# Copyright (c) 2026 Justin Arndt. All rights reserved.
# Licensed under the GNU GPLv3. For commercial licensing and proprietary
# hardware mapping, see the LICENSE file (dual-licensing notice at top).
"""phenomenological.py -- spacetime parity-check construction + noise sampling +
two-sided witness extraction for BB codes under phenomenological noise.

Phenomenological noise model: d rounds of noisy syndrome measurement on a BB code
with spatial parity-check H_Z (r x n). Each round t introduces:
  - new data errors e_t (iid Bernoulli(p) per qubit, n bits)
  - measurement errors m_t (iid Bernoulli(q) per syndrome bit, r bits, rounds 1..d)
The final round d+1 has a perfect measurement (m_{d+1} = 0).

The spacetime syndrome difference vector is:
  Δ_t = H_Z · e_t + m_t + m_{t-1}     for t = 1..d     (m_0 = 0)
  Δ_{d+1} = H_Z · e_{d+1} + m_d       (perfect final round)

This defines a spacetime parity-check matrix H_st of size
  ((d+1)*r) x ((d+1)*n + d*r)
acting on the spacetime error vector x = (e_1, ..., e_{d+1}, m_1, ..., m_d).

H_st is NOT circulant in the time direction, but its spatial blocks are — and
GenericCert.lean's validateGenericRun_sound applies to any F₂ matrix.

Gate-count projection: the spacetime checker is d+1 copies of the spatial
checker (circulant, ~w gates each) plus d*r gates for the bidiagonal
measurement-error chain. For the gross code (r=72) with d=12 rounds:
  (d+1)*2082 + d*72 ≈ 27k gates, depth ≈ spatial_depth + O(1) ≈ 12.

Two-sided witness extraction: we solve H_orth_st^T w = residual over GF(2).
For CSS codes, H_orth_st is constructed from H_X with the same temporal chain.
"""

from __future__ import annotations

from typing import Tuple

import numpy as np
import scipy.sparse as sp

from codes import BBCode, get_code
import logical as lg


def build_H_st(code: BBCode, d: int) -> Tuple[np.ndarray, np.ndarray, int, int]:
    """Build the spacetime parity-check matrices H_st_Z and H_st_X for `d`
    rounds of phenomenological noise.

    Returns (H_st_Z, H_st_X, n_st, r_st) where:
      H_st_Z: ((d+1)*r, (d+1)*n + d*r) uint8 — detects X-type spacetime errors
      H_st_X: ((d+1)*r, (d+1)*n + d*r) uint8 — the orthogonal check for witness extraction
      n_st: number of spacetime error bits = (d+1)*n + d*r
      r_st: number of spacetime syndrome bits = (d+1)*r
    """
    HZ = code.HZ()  # (r, n)
    HX = code.HX()  # (r, n)
    r, n = HZ.shape
    assert HX.shape == (r, n)

    D = d + 1  # total data-error rounds (d noisy + 1 perfect)
    n_st = D * n + d * r
    r_st = D * r

    H_st_Z = np.zeros((r_st, n_st), dtype=np.uint8)
    H_st_X = np.zeros((r_st, n_st), dtype=np.uint8)

    for t in range(D):
        row_start = t * r
        col_data = t * n
        # spatial block: H_Z acting on e_t
        H_st_Z[row_start:row_start + r, col_data:col_data + n] = HZ
        H_st_X[row_start:row_start + r, col_data:col_data + n] = HX

        # temporal chain on measurement errors (columns D*n .. D*n + d*r - 1)
        # Δ_t depends on m_t and m_{t-1}. H_st_X does NOT act on measurement
        # columns (measurement errors are Z-syndrome noise, invisible to X-checks).
        # This makes H_st_X · H_st_Z^T = 0 (CSS orthogonality).
        if t < d:  # m_t
            col_meas_t = D * n + t * r
            H_st_Z[row_start:row_start + r, col_meas_t:col_meas_t + r] ^= np.eye(r, dtype=np.uint8)
        if t > 0 and (t - 1) < d:  # m_{t-1}
            col_meas_prev = D * n + (t - 1) * r
            H_st_Z[row_start:row_start + r, col_meas_prev:col_meas_prev + r] ^= np.eye(r, dtype=np.uint8)

    return H_st_Z, H_st_X, n_st, r_st


def sample_phenomenological(
    code: BBCode, d: int, p_data: float, p_meas: float, rng: np.random.Generator
) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Sample a phenomenological noise instance.

    Returns (x_st, syn_st, n_st) where:
      x_st: spacetime error vector (n_st,) uint8
      syn_st: spacetime syndrome ((d+1)*r,) uint8
      n_st: length of x_st
    """
    n = code.n
    r = code.group_size  # = l*m = number of Z-checks
    D = d + 1

    # data errors: D rounds
    e_rounds = (rng.random((D, n)) < p_data).astype(np.uint8)
    # measurement errors: d rounds (last round is perfect)
    m_rounds = (rng.random((d, r)) < p_meas).astype(np.uint8)

    # pack into spacetime error vector
    x_st = np.concatenate([e_rounds.ravel(), m_rounds.ravel()])

    # syndrome via H_st
    H_st_Z, _, n_st, r_st = build_H_st(code, d)
    syn_st = (H_st_Z @ x_st) % 2

    return x_st, syn_st.astype(np.uint8), n_st


def decode_spacetime_osd0(
    H_st_Z: np.ndarray, syn_st: np.ndarray
) -> np.ndarray:
    """Decode a spacetime syndrome using OSD-0 on the full H_st matrix.

    This is a REFERENCE decoder — it is slow for large d*n but correct, and
    the certification layer is decoder-agnostic. A production decoder would
    use a sliding-window or matching approach on the spacetime Tanner graph.
    """
    n_st = H_st_Z.shape[1]
    # uniform priors (no BP pre-pass for the reference decoder)
    posterior = np.zeros(n_st, dtype=np.float64)
    from decoder import osd0
    e_hat = osd0(H_st_Z, syn_st, posterior)
    assert e_hat is not None, "OSD-0 failed to find a consistent correction"
    return e_hat


def certify_spacetime_run(
    code: BBCode, d: int, p_data: float, p_meas: float, seed: int
) -> dict:
    """One full phenomenological decode + two-sided certification run.

    Returns a dict with code, d, p_data, p_meas, outcome, weights, and whether
    the witness is valid (verified by the GF(2) linear algebra that the Lean
    GenericCert layer would kernel-check on the same H_st).
    """
    rng = np.random.default_rng(seed)
    H_st_Z, H_st_X, n_st, r_st = build_H_st(code, d)

    x_st, syn_st, _ = sample_phenomenological(code, d, p_data, p_meas, rng)

    # decode
    e_hat = decode_spacetime_osd0(H_st_Z, syn_st)

    # verify syndrome consistency
    syn_hat = (H_st_Z @ e_hat) % 2
    assert np.array_equal(syn_hat, syn_st), "decoder postcondition violated"

    # residual
    residual = (e_hat ^ x_st).astype(np.uint8)

    # two-sided witness extraction using the GENERIC framework
    # H_orth = H_st_X (the orthogonal check matrix for CSS spacetime codes)
    outcome, witness = lg.logical_witness(H_st_X, residual)

    # local verification (mirrors GenericCert.validateGenericRun_sound)
    if outcome == "success":
        r_check = (H_st_X.T @ witness) % 2
        assert np.array_equal(r_check, residual), "success witness invalid"
    else:
        assert (H_st_X @ witness % 2).sum() == 0, "failure witness: H_X z ≠ 0"
        assert int(witness @ residual) % 2 == 1, "failure witness: ⟨z,r⟩ ≠ 1"

    # residual in ker H_st_Z (undetectable)?
    assert np.array_equal((H_st_Z @ residual) % 2, np.zeros(r_st, dtype=np.uint8)), \
        "residual not in ker H_st_Z"

    D = d + 1
    n = code.n
    r = code.group_size
    data_weight = int(x_st[:D * n].sum())
    meas_weight = int(x_st[D * n:].sum())

    return {
        "code": code.name, "d": d, "p_data": p_data, "p_meas": p_meas,
        "seed": seed, "outcome": outcome,
        "n_st": n_st, "r_st": r_st,
        "data_error_weight": data_weight,
        "measurement_error_weight": meas_weight,
        "decoder": "OSD-0 (reference, full H_st)",
        "gate_count_projection": (D * 2 * sum(max(len(s) - 1, 0) for s in
            [code.supp_a, code.supp_b]) * code.group_size + d * r),
    }


def run_phenom_campaign(
    code_name: str, d: int, p_data: float, p_meas: float,
    n_trials: int, seed: int
) -> dict:
    """Run n_trials phenomenological decoding + certification trials.
    Returns summary statistics including logical error rate with Wilson interval.
    """
    code = get_code(code_name)
    failures = 0
    successes = 0
    for trial in range(n_trials):
        res = certify_spacetime_run(code, d, p_data, p_meas, seed + trial)
        if res["outcome"] == "failure":
            failures += 1
        else:
            successes += 1

    # Wilson 95% interval
    from bench import wilson
    ler, lo, hi = wilson(failures, n_trials)

    return {
        "code": code_name, "n": code.n, "d": d,
        "p_data": p_data, "p_meas": p_meas,
        "n_trials": n_trials, "seed": seed,
        "successes": successes, "failures": failures,
        "ler": ler, "wilson_lo": lo, "wilson_hi": hi,
        "n_st": res["n_st"], "r_st": res["r_st"],
        "gate_count_projection": res["gate_count_projection"],
    }


if __name__ == "__main__":
    import json
    # quick self-test: one run
    res = certify_spacetime_run(get_code("code72"), d=3, p_data=0.01,
                                p_meas=0.01, seed=42)
    print("single run:", json.dumps(res, indent=2))
    # small campaign
    camp = run_phenom_campaign("code72", d=3, p_data=0.02, p_meas=0.02,
                               n_trials=200, seed=1000)
    print("campaign:", json.dumps(camp, indent=2))
