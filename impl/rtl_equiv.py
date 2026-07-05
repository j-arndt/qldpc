"""rtl_equiv.py -- Stage B equivalence harness for the Lean-emitted RTL.

Checks, per emitted netlist (rtl/<code>_netlist.json + _checker.v):

  (1) EXACT LINEAR-MAP EQUALITY: the JSON taps define each linear layer's
      matrix directly; we build those matrices and compare them ENTRY-BY-ENTRY
      against the independent dense ground truth of codes.py (H_Z blocks,
      H_X^T blocks, H_X blocks). This is complete -- stronger than basis
      testing, which it subsumes.
  (2) FULL-CIRCUIT BEHAVIOUR: simulate the Boolean circuits (comparators,
      reduction-parity) on live decode runs from the actual BP+OSD pipeline and
      on adversarially corrupted variants; verdicts must match the pipeline's
      own semantics (numpy recomputation) on every run.
  (3) PRINTER CROSS-CHECK: parse the tap indices out of the emitted Verilog
      text and compare them set-for-set with the JSON netlist, so the two
      trusted printers cannot silently diverge.
  (4) GATE REPORT: 2-input-gate counts and depths for the ROADMAP's
      complexity claim, written to rtl/gate_report.json.

Exit code 0 iff every check passes.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import numpy as np

import structured as st
import logical as lg
from codes import get_code
from decoder import decode_batch

REPO = Path(__file__).resolve().parent.parent
RTL = REPO / "rtl"

CODES = {"code72": "code72", "gross144": "gross144"}
SEED = 20260708


def taps_to_matrix(taps, n_out, n_in):
    """taps[g] = list of input bit indices XORed into output bit g."""
    M = np.zeros((n_out, n_in), dtype=np.uint8)
    for g, ts in enumerate(taps):
        for t in ts:
            M[g, t] ^= 1
    return M


def check_linear_layers(name, nl, code):
    lm = code.l * code.m
    HZ = code.HZ()          # (lm, 2lm) = [B^T | A^T]
    HX = code.HX()          # (lm, 2lm) = [A | B]
    ok = True

    # syndrome layer: syn[g] = XOR e1[taps_b] ^ XOR e2[taps_a]  == H_Z @ (e1|e2)
    Mb = taps_to_matrix(nl["syn_taps_b_on_e1"], lm, lm)
    Ma = taps_to_matrix(nl["syn_taps_a_on_e2"], lm, lm)
    ok &= np.array_equal(Mb, HZ[:, :lm]) and np.array_equal(Ma, HZ[:, lm:])
    print(f"  [{name}] syndrome layer == H_Z blocks (exact): "
          f"{np.array_equal(Mb, HZ[:, :lm]) and np.array_equal(Ma, HZ[:, lm:])}")

    # stabilizer layer: sw1 = A^T w, sw2 = B^T w  (H_X^T blocks)
    SA = taps_to_matrix(nl["stab_taps_a_on_w"], lm, lm)
    SB = taps_to_matrix(nl["stab_taps_b_on_w"], lm, lm)
    okA = np.array_equal(SA, HX[:, :lm].T)
    okB = np.array_equal(SB, HX[:, lm:].T)
    ok &= okA and okB
    print(f"  [{name}] stabilizer layer == H_X^T blocks (exact): {okA and okB}")

    # failure layer: fx = A z1 ^ B z2  (H_X blocks)
    FA = taps_to_matrix(nl["failx_taps_a_on_z1"], lm, lm)
    FB = taps_to_matrix(nl["failx_taps_b_on_z2"], lm, lm)
    okFA = np.array_equal(FA, HX[:, :lm])
    okFB = np.array_equal(FB, HX[:, lm:])
    ok &= okFA and okFB
    print(f"  [{name}] failure layer == H_X blocks (exact): {okFA and okFB}")
    return bool(ok)


def simulate_circuits(nl, lm, obs, e1, e2, i1, i2, wv, z1, z2):
    """Bit-exact simulation of the emitted circuits (flat lm-bit uint8 vectors)."""
    def lin(taps_x, x, taps_y, y):
        out = np.zeros(lm, dtype=np.uint8)
        for g in range(lm):
            v = 0
            for t in taps_x[g]:
                v ^= int(x[t])
            for t in taps_y[g]:
                v ^= int(y[t])
            out[g] = v
        return out

    syn = lin(nl["syn_taps_b_on_e1"], e1, nl["syn_taps_a_on_e2"], e2)
    syn_i = lin(nl["syn_taps_b_on_e1"], i1, nl["syn_taps_a_on_e2"], i2)

    def lin1(taps, x):
        out = np.zeros(lm, dtype=np.uint8)
        for g in range(lm):
            v = 0
            for t in taps[g]:
                v ^= int(x[t])
            out[g] = v
        return out

    sw1 = lin1(nl["stab_taps_a_on_w"], wv)
    sw2 = lin1(nl["stab_taps_b_on_w"], wv)
    fx = lin1(nl["failx_taps_a_on_z1"], z1) ^ lin1(nl["failx_taps_b_on_z2"], z2)
    r1, r2 = e1 ^ i1, e2 ^ i2
    syn_ok_corr = int(not (syn ^ obs).any())
    syn_ok_inj = int(not (syn_i ^ obs).any())
    success_ok = int((not (sw1 ^ r1).any()) and (not (sw2 ^ r2).any()))
    fail_ok = int((not fx.any()) and ((int((z1 & r1).sum()) % 2) ^ (int((z2 & r2).sum()) % 2)))
    return syn_ok_corr, syn_ok_inj, success_ok, fail_ok


def check_behaviour(name, nl, code, n_runs=40, p=0.05):
    lm = code.l * code.m
    HX, HZ = code.HX(), code.HZ()
    rng = np.random.default_rng(SEED)
    err = (rng.random((n_runs, 2, code.l, code.m)) < p).astype(np.uint8)
    syn = st.np_syndromeZ(code, err[:, 0], err[:, 1])
    e_hat, _ = decode_batch(code, syn, p, HZ=HZ)
    err_flat = st.flatten_qubitvec(err[:, 0], err[:, 1])

    bad = 0
    for b in range(n_runs):
        obs = st.flatten_lm(syn[b])
        c1f, c2f = e_hat[b][:lm], e_hat[b][lm:]
        i1f, i2f = err_flat[b][:lm], err_flat[b][lm:]
        r = (e_hat[b] ^ err_flat[b]).astype(np.uint8)
        outcome, wit = lg.logical_witness(HX, r)
        if outcome == "success":
            wv, z1, z2 = wit.astype(np.uint8), np.zeros(lm, np.uint8), np.zeros(lm, np.uint8)
        else:
            wv = np.zeros(lm, np.uint8)
            z1, z2 = wit[:lm].astype(np.uint8), wit[lm:].astype(np.uint8)
        sc, si, so, fo = simulate_circuits(nl, lm, obs, c1f, c2f, i1f, i2f, wv, z1, z2)
        # expectations from pipeline semantics
        exp_sc = exp_si = 1
        exp_so = 1 if outcome == "success" else 0  # zero witness never certifies nonzero r
        if outcome == "success" and not r.any():
            exp_so = 1
        exp_fo = 1 if outcome == "failure" else 0
        if (sc, si) != (exp_sc, exp_si) or so != exp_so or fo != exp_fo:
            bad += 1
        # corrupted variant: flip one observed bit -> syndrome check must fail
        obs_bad = obs.copy()
        obs_bad[rng.integers(lm)] ^= 1
        sc2, si2, _, _ = simulate_circuits(nl, lm, obs_bad, c1f, c2f, i1f, i2f, wv, z1, z2)
        if sc2 != 0 or si2 != 0:
            bad += 1
    print(f"  [{name}] full-circuit behaviour on {n_runs} live runs + corrupted variants: "
          f"{'OK' if bad == 0 else f'{bad} MISMATCHES'}")
    return bad == 0


def cross_check_verilog(name, nl, vpath, lm):
    """Parse tap indices from the .v text; compare with the JSON netlist."""
    text = vpath.read_text()
    ok = True
    for sig, key_x, key_y, nx, ny in [
        ("syn", "syn_taps_b_on_e1", "syn_taps_a_on_e2", "e1", "e2"),
        ("sw1", "stab_taps_a_on_w", None, "wv", None),
        ("sw2", "stab_taps_b_on_w", None, "wv", None),
        ("fx", "failx_taps_a_on_z1", "failx_taps_b_on_z2", "z1", "z2"),
    ]:
        for g in range(lm):
            mline = re.search(rf"assign {sig}\[{g}\] = (.+);", text)
            if not mline:
                ok = False
                continue
            rhs = mline.group(1)
            got_x = sorted(int(t) for t in re.findall(rf"{nx}\[(\d+)\]", rhs))
            want_x = sorted(nl[key_x][g])
            if got_x != want_x:
                ok = False
            if key_y:
                got_y = sorted(int(t) for t in re.findall(rf"{ny}\[(\d+)\]", rhs))
                if got_y != sorted(nl[key_y][g]):
                    ok = False
    print(f"  [{name}] Verilog<->JSON printer cross-check (all taps): {'OK' if ok else 'DIVERGED'}")
    return ok


def gate_report(name, nl, lm):
    def xors_of(taps_list):
        return sum(max(len(t) - 1, 0) for t in taps_list)
    syn_x = xors_of(nl["syn_taps_b_on_e1"]) + xors_of(nl["syn_taps_a_on_e2"]) + lm
    stab_x = xors_of(nl["stab_taps_a_on_w"]) + xors_of(nl["stab_taps_b_on_w"])
    fail_x = xors_of(nl["failx_taps_a_on_z1"]) + xors_of(nl["failx_taps_b_on_z2"]) + lm
    cmp_x = 2 * lm            # syn^obs twice (corr + inj)
    red_or = 4 * (lm - 1)     # four ~| reductions
    parity_x = 2 * (lm - 1) + 2 * lm  # two ^(z&r) reductions + ANDs
    total_2in = syn_x * 2 + stab_x + fail_x + cmp_x + red_or + parity_x
    rep = {
        "code": name, "word_bits": lm,
        "xor2_syndrome_layer(x2 for corr+inj)": syn_x * 2,
        "xor2_stabilizer_layer": stab_x,
        "xor2_failure_layer": fail_x,
        "xor2_comparators": cmp_x,
        "or2_reductions": red_or,
        "xor2_and2_parity": parity_x,
        "total_2input_gates_approx": total_2in,
        "combinational_depth_approx": int(np.ceil(np.log2(max(lm, 2))) + 4),
    }
    print(f"  [{name}] gate report: ~{total_2in} two-input gates, "
          f"depth ~{rep['combinational_depth_approx']} (ROADMAP claim: ~10^3)")
    return rep


def main() -> int:
    all_ok = True
    reports = []
    for name in CODES:
        code = get_code(name)
        nl = json.loads((RTL / f"{name}_netlist.json").read_text())
        print(f"== {name} (n={code.n}) ==")
        all_ok &= check_linear_layers(name, nl, code)
        all_ok &= check_behaviour(name, nl, code)
        all_ok &= cross_check_verilog(name, nl, RTL / f"{name}_checker.v", code.l * code.m)
        reports.append(gate_report(name, nl, code.l * code.m))
    (RTL / "gate_report.json").write_text(json.dumps(reports, indent=2))
    print("=" * 60)
    print("RTL EQUIVALENCE:", "ALL CHECKS PASSED" if all_ok else "FAILURES FOUND")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
