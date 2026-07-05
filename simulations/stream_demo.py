# Copyright (c) 2026 Justin Arndt. All rights reserved.
# Licensed under the GNU GPLv3. For commercial licensing and proprietary
# hardware mapping, see the LICENSE file (dual-licensing notice at top).
"""stream_demo.py -- runnable, in-sandbox streaming demonstration of the
Lean-emitted checker netlist at the LOGICAL level (no HDL simulator required).

This is the software analogue of "checker on the syndrome bus at line rate": it
streams a large matrix of live decode runs (from the real BP+OSD pipeline) plus
adversarially corrupted variants through the exact gate-level netlist emitted by
Lean (`../hardware/<code>_netlist.json`), and asserts that every verdict matches
the mathematical expectation:

  * legitimate correction      -> success_ok = 1, fail_ok = 0
  * certified logical failure   -> success_ok = 0, fail_ok = 1
  * corrupted syndrome/vector   -> syn_ok = 0 (firewall rejects)

It reports gate-evaluations/sec as a throughput proxy. This does NOT model SFQ
pulse timing (that is `tb_josim.sp`); it validates the netlist's Boolean
behaviour exhaustively over the stream. Every gate evaluated here is one the
Lean kernel proved equal to the certified validator (circuits_eq_pValidateRun).

Usage:  python3 stream_demo.py --code gross144 --runs 5000
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np

# resolve imports against ../impl before importing the pipeline modules
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "impl"))

# reuse the audited gate-level netlist simulator from the equivalence harness
from rtl_equiv import simulate_circuits
import structured as st
import logical as lg
from codes import get_code
from decoder import decode_batch

HW = Path(__file__).resolve().parent.parent / "hardware"


def _unpack(x: int, lm: int) -> np.ndarray:
    return np.array([(x >> i) & 1 for i in range(lm)], dtype=np.uint8)


def run(code_name: str, n_runs: int, p: float, seed: int) -> int:
    code = get_code(code_name)
    lm = code.l * code.m
    nl = json.loads((HW / f"{code_name}_netlist.json").read_text())
    HX, HZ = code.HX(), code.HZ()

    rng = np.random.default_rng(seed)
    err = (rng.random((n_runs, 2, code.l, code.m)) < p).astype(np.uint8)
    syn = st.np_syndromeZ(code, err[:, 0], err[:, 1])
    e_hat, _ = decode_batch(code, syn, p, HZ=HZ)
    err_flat = st.flatten_qubitvec(err[:, 0], err[:, 1])

    gate_evals = (nl_gate_count(nl))
    ok = 0
    n_success = n_failure = n_rejected = 0
    t0 = time.perf_counter()
    for b in range(n_runs):
        obs = st.flatten_lm(syn[b])
        c1, c2 = e_hat[b][:lm], e_hat[b][lm:]
        i1, i2 = err_flat[b][:lm], err_flat[b][lm:]
        r = (e_hat[b] ^ err_flat[b]).astype(np.uint8)
        outcome, wit = lg.logical_witness(HX, r)
        if outcome == "success":
            wv, z1, z2 = wit.astype(np.uint8), np.zeros(lm, np.uint8), np.zeros(lm, np.uint8)
            n_success += 1
        else:
            wv, z1, z2 = np.zeros(lm, np.uint8), wit[:lm].astype(np.uint8), wit[lm:].astype(np.uint8)
            n_failure += 1
        sc, si, so, fo = simulate_circuits(nl, lm, obs, c1, c2, i1, i2, wv, z1, z2)
        exp_so = 1 if (outcome == "success") else 0
        exp_fo = 1 if (outcome == "failure") else 0
        good = (sc == 1 and si == 1 and so == exp_so and fo == exp_fo)

        # adversarial: corrupt the streamed correction -> firewall must reject
        c1_bad = c1.copy()
        c1_bad[rng.integers(lm)] ^= 1
        sc2, _, _, _ = simulate_circuits(nl, lm, obs, c1_bad, c2, i1, i2, wv, z1, z2)
        rejected = (sc2 == 0)
        n_rejected += rejected
        ok += good and rejected
    dt = time.perf_counter() - t0

    total_gate_evals = gate_evals * 2 * n_runs  # legit + corrupted pass per run
    print(f"code {code_name} (n={code.n}, {lm}-bit words): streamed {n_runs} runs")
    print(f"  outcomes: {n_success} success, {n_failure} failure (all two-sided certified)")
    print(f"  verdict-match + adversarial-rejection: {ok}/{n_runs} "
          f"({'ALL OK' if ok == n_runs else 'MISMATCH'})")
    print(f"  wall: {dt:.2f}s  |  ~{total_gate_evals/dt/1e6:.1f}M gate-evals/s "
          f"(software proxy; {gate_evals} gates/run x 2 passes)")
    return 0 if ok == n_runs else 1


def nl_gate_count(nl) -> int:
    def xo(t):
        return sum(max(len(x) - 1, 0) for x in t)
    lm = len(nl["syn_taps_b_on_e1"])
    return (xo(nl["syn_taps_b_on_e1"]) + xo(nl["syn_taps_a_on_e2"]) + lm
            + xo(nl["stab_taps_a_on_w"]) + xo(nl["stab_taps_b_on_w"])
            + xo(nl["failx_taps_a_on_z1"]) + xo(nl["failx_taps_b_on_z2"]) + lm)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--code", default="gross144", choices=["code72", "gross144"])
    ap.add_argument("--runs", type=int, default=5000)
    ap.add_argument("--p", type=float, default=0.05)
    ap.add_argument("--seed", type=int, default=20260709)
    a = ap.parse_args()
    return run(a.code, a.runs, a.p, a.seed)


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "impl"))
    sys.exit(main())
