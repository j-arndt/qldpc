"""decoder.py -- batched normalized min-sum BP + OSD-0 for X-error decoding of BB codes.

The heuristic decoder lives OUTSIDE the mathematical firewall: nothing here is
formally verified, and nothing here needs to be. Every output is gated by the
verified certificate layer (proofs/DecoderCert.lean) via logical.py's witness
extraction + certgen.py's kernel-checked per-run certificates.

Structure exploitation: BP messages live on the (l, m) torus in per-slot arrays
(one slot per monomial of the code polynomials), and move between the check frame
and the variable frame by np.roll -- the circulant structure turns sparse
gather/scatter into whole-array rolls.

Graph (from proofs/BBCode.lean syndromeZ): Z-check g touches
  left-block  vars (k + g) for k in supp(b)   [slots 0..2]
  right-block vars (k + g) for k in supp(a)   [slots 3..5]
"""

from __future__ import annotations

from typing import Optional, Tuple

import numpy as np

import structured as st
import logical as lg


def _slots(code):
    """Slot list: (block, (ki, kj)) for the 6 edges per Z-check."""
    return [(0, k) for k in code.supp_b] + [(1, k) for k in code.supp_a]


def bp_minsum_batch(
    code,
    syndromes: np.ndarray,
    p: float,
    max_iters: int = 60,
    alpha: float = 0.9,
    early_stop: bool = True,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Batched normalized min-sum BP.

    syndromes: (B, l, m) uint8 Z-syndromes. Returns (e_hat, converged, posterior):
      e_hat:     (B, 2, l, m) uint8 hard decision,
      converged: (B,) bool -- syndrome reproduced,
      posterior: (B, 2, l, m) float64 LLRs (large positive = likely no error).
    """
    l, m = code.l, code.m
    B = syndromes.shape[0]
    slots = _slots(code)
    S = len(slots)
    llr0 = float(np.log((1.0 - p) / p))
    sgn_syn = 1.0 - 2.0 * syndromes.astype(np.float64)  # (B, l, m), +1 / -1

    V2C = np.full((B, S, l, m), llr0, dtype=np.float64)  # var->check, check frame
    C2V_var = np.zeros((B, S, l, m), dtype=np.float64)   # check->var, var frame
    slot_idx = np.arange(S)[None, :, None, None]

    e_hat = np.zeros((B, 2, l, m), dtype=np.uint8)
    posterior = np.full((B, 2, l, m), llr0, dtype=np.float64)
    converged = np.zeros(B, dtype=bool)

    for _ in range(max_iters):
        # ---- check update (check frame, leave-one-out over the 6 slots) ----
        signs = np.where(V2C >= 0.0, 1.0, -1.0)
        prod_sign = signs.prod(axis=1) * sgn_syn                  # (B, l, m)
        mags = np.abs(V2C)
        part = np.partition(mags, 1, axis=1)
        min1, min2 = part[:, 0], part[:, 1]                       # (B, l, m)
        amin = mags.argmin(axis=1)                                # (B, l, m)
        loo_min = np.where(slot_idx == amin[:, None], min2[:, None], min1[:, None])
        loo_sign = prod_sign[:, None] * signs                     # (+-1) leave-one-out
        C2V_check = alpha * loo_sign * loo_min                    # (B, S, l, m)

        # ---- to var frame: roll by +k per slot ----
        for t, (_blk, (ki, kj)) in enumerate(slots):
            C2V_var[:, t] = np.roll(C2V_check[:, t], shift=(ki, kj), axis=(-2, -1))

        # ---- var update ----
        posterior = np.full((B, 2, l, m), llr0, dtype=np.float64)
        for t, (blk, _k) in enumerate(slots):
            posterior[:, blk] += C2V_var[:, t]
        for t, (blk, (ki, kj)) in enumerate(slots):
            v2c_var = posterior[:, blk] - C2V_var[:, t]
            V2C[:, t] = np.roll(v2c_var, shift=(-ki, -kj), axis=(-2, -1))

        # ---- hard decision + early stop ----
        e_hat = (posterior < 0.0).astype(np.uint8)
        syn_hat = st.np_syndromeZ(code, e_hat[:, 0], e_hat[:, 1])
        converged = np.all(syn_hat == syndromes, axis=(-2, -1))
        if early_stop and bool(converged.all()):
            break

    return e_hat, converged, posterior


def osd0(HZ: np.ndarray, syndrome_flat: np.ndarray, posterior_flat: np.ndarray
         ) -> Optional[np.ndarray]:
    """Order-0 ordered-statistics decoding: solve H_Z e = s with support preference
    for the least-reliable (most-likely-error) columns per BP posteriors."""
    n = HZ.shape[1]
    order = np.argsort(posterior_flat, kind="stable")  # ascending: likely-error first
    aug = np.concatenate([HZ[:, order], syndrome_flat.reshape(-1, 1).astype(np.uint8)],
                         axis=1)
    R, pivots = lg.gf2_row_reduce(aug)
    x_perm = np.zeros(n, dtype=np.uint8)
    for i, pc in enumerate(pivots):
        if pc == n:
            return None  # inconsistent system -- impossible for genuine syndromes
        x_perm[pc] = R[i, n]
    e = np.zeros(n, dtype=np.uint8)
    e[order] = x_perm
    return e


def decode_batch(code, syndromes: np.ndarray, p: float, max_iters: int = 60,
                 alpha: float = 0.9, HZ: Optional[np.ndarray] = None
                 ) -> Tuple[np.ndarray, np.ndarray]:
    """BP + OSD-0 pipeline. syndromes: (B, l, m) uint8.

    Returns (e_hat_flat, used_osd): (B, n) uint8 corrections (all syndrome-consistent),
    and a (B,) bool mask of which trials needed the OSD fallback.
    """
    B = syndromes.shape[0]
    if HZ is None:
        HZ = code.HZ()
    e_hat, converged, posterior = bp_minsum_batch(code, syndromes, p, max_iters, alpha)
    e_flat = st.flatten_qubitvec(e_hat[:, 0], e_hat[:, 1])
    post_flat = st.flatten_qubitvec(posterior[:, 0], posterior[:, 1])
    used_osd = ~converged
    for b in np.nonzero(used_osd)[0]:
        s_flat = st.flatten_lm(syndromes[b])
        e_osd = osd0(HZ, s_flat, post_flat[b])
        assert e_osd is not None, "OSD-0 hit an inconsistent system on a genuine syndrome"
        e_flat[b] = e_osd
    # postcondition: every correction reproduces its syndrome
    e1, e2 = st.unflatten_qubitvec(e_flat, code.l, code.m)
    syn = st.np_syndromeZ(code, e1, e2)
    assert np.array_equal(syn, syndromes), "decode_batch postcondition violated"
    return e_flat, used_osd


# ---------------------------------------------------------------------------
# smoke test
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import time
    from codes import get_code

    rng = np.random.default_rng(7)
    code = get_code("code72")
    HX, HZ = code.HX(), code.HZ()
    B, p = 400, 0.02

    err = (rng.random((B, 2, code.l, code.m)) < p).astype(np.uint8)
    syn = st.np_syndromeZ(code, err[:, 0], err[:, 1])

    t0 = time.time()
    e_hat_flat, used_osd = decode_batch(code, syn, p)
    dt = time.time() - t0

    err_flat = st.flatten_qubitvec(err[:, 0], err[:, 1])
    fails = 0
    for b in range(B):
        r = (e_hat_flat[b] ^ err_flat[b]).astype(np.uint8)
        outcome, _w = lg.logical_witness(HX, r)
        fails += outcome == "failure"
    print(f"code72 p={p}: B={B} decoded in {dt:.2f}s "
          f"({1e3 * dt / B:.2f} ms/trial), OSD used on {int(used_osd.sum())}, "
          f"logical failures {fails}/{B}")
