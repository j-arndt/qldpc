# Copyright (c) 2026 Justin Arndt. All rights reserved.
# Licensed under the GNU GPLv3. For commercial licensing and proprietary
# hardware mapping, see the LICENSE file (dual-licensing notice at top).
"""
crosscheck.py -- THE ACCEPTANCE GATE.

Must be run (and pass) right after codes.py / structured.py, before anything else in
the pipeline is trusted. Checks:

  (i)   dense H_X, H_Z built independently from the convolution definition (nested
        loops, codes.py's build_HX_naive/build_HZ_naive -- no cleverness, no shared
        code with structured.py's roll-based path);
  (ii)  roll-based (numpy + jax) and CSR and dense syndromes agree on 100 random
        errors, for every registered code;
  (iii) H_X @ H_Z.T % 2 == 0 for every code (CSS validity, Lean's `css_matrix`);
  (iv)  logical counts k = n - rank(H_X) - rank(H_Z) match expectation;
  (v)   logical_witness two-sidedness: success case (r = H_X^T w for random w) and
        failure case (r = a known logical operator) both handled correctly.

All asserts must pass or the script raises / exits nonzero.
"""

from __future__ import annotations

import sys
import time

import numpy as np

from codes import REGISTRY, BBCode
import structured as st
import logical as lg

SEED = 20260704
RNG = np.random.default_rng(SEED)


def check_code(code: BBCode, n_random_errors: int = 100) -> None:
    print(f"\n=== crosscheck: {code.name} (l={code.l}, m={code.m}, n={code.n}) ===")
    l, m, lm = code.l, code.m, code.group_size

    # (i) dense H_X, H_Z from scratch (nested-loop convolution definition).
    HX = code.build_HX_naive()
    HZ = code.build_HZ_naive()
    assert HX.shape == (lm, code.n), f"HX shape mismatch: {HX.shape}"
    assert HZ.shape == (lm, code.n), f"HZ shape mismatch: {HZ.shape}"
    row_weight_x = HX.sum(axis=1)
    row_weight_z = HZ.sum(axis=1)
    assert np.all(row_weight_x == 6), f"HX row weight not uniformly 6: {set(row_weight_x)}"
    assert np.all(row_weight_z == 6), f"HZ row weight not uniformly 6: {set(row_weight_z)}"
    print(f"  (i)   dense HX/HZ built from scratch: shapes {HX.shape}, row weight 6. OK")

    # scipy CSR versions built from the same dense arrays (independent representation,
    # not sharing arithmetic code with roll-based path).
    HX_csr = code.HX_csr()
    HZ_csr = code.HZ_csr()
    assert np.array_equal(HX_csr.toarray().astype(np.uint8), HX)
    assert np.array_equal(HZ_csr.toarray().astype(np.uint8), HZ)

    # (ii) roll-based (numpy + jax) vs CSR vs dense syndromes agree on random errors.
    t0 = time.time()
    jit_synZ = st.make_jit_syndromeZ(code) if st._HAVE_JAX else None
    jit_synX = st.make_jit_syndromeX(code) if st._HAVE_JAX else None

    max_mismatch_np = 0
    max_mismatch_jax = 0
    for trial in range(n_random_errors):
        e1 = RNG.integers(0, 2, size=(l, m), dtype=np.uint8)
        e2 = RNG.integers(0, 2, size=(l, m), dtype=np.uint8)
        e_flat = st.flatten_qubitvec(e1, e2)

        # dense ground truth
        s_dense = (HZ @ e_flat) % 2

        # CSR
        s_csr = np.asarray(HZ_csr.dot(e_flat) % 2).astype(np.uint8).reshape(-1)

        # numpy roll-based
        s_np_lm = st.np_syndromeZ(code, e1, e2)
        s_np = st.flatten_lm(s_np_lm)

        assert np.array_equal(s_dense, s_csr), f"trial {trial}: dense vs CSR mismatch"
        mism = np.count_nonzero(s_dense != s_np)
        max_mismatch_np = max(max_mismatch_np, mism)
        assert mism == 0, f"trial {trial}: dense vs numpy-roll syndromeZ mismatch ({mism} bits)"

        if st._HAVE_JAX:
            s_jax_lm = np.asarray(jit_synZ(e1, e2))
            s_jax = st.flatten_lm(s_jax_lm)
            mismj = np.count_nonzero(s_dense != s_jax)
            max_mismatch_jax = max(max_mismatch_jax, mismj)
            assert mismj == 0, f"trial {trial}: dense vs jax-roll syndromeZ mismatch ({mismj} bits)"

        # Also cross-check syndromeX (H_X = [A|B]) the same way, using f-vectors.
        f1 = RNG.integers(0, 2, size=(l, m), dtype=np.uint8)
        f2 = RNG.integers(0, 2, size=(l, m), dtype=np.uint8)
        f_flat = st.flatten_qubitvec(f1, f2)
        sx_dense = (HX @ f_flat) % 2
        sx_np = st.flatten_lm(st.np_syndromeX(code, f1, f2))
        assert np.array_equal(sx_dense, sx_np), f"trial {trial}: syndromeX dense vs numpy mismatch"
        if st._HAVE_JAX:
            sx_jax = st.flatten_lm(np.asarray(jit_synX(f1, f2)))
            assert np.array_equal(sx_dense, sx_jax), f"trial {trial}: syndromeX dense vs jax mismatch"

    dt = time.time() - t0
    print(f"  (ii)  {n_random_errors} random errors: roll(numpy)/roll(jax)/CSR/dense all agree "
          f"for syndromeZ and syndromeX. ({dt:.2f}s)")

    # (iii) CSS validity: H_X @ H_Z^T = 0 mod 2.
    prod = (HX @ HZ.T) % 2
    assert np.all(prod == 0), "H_X @ H_Z^T != 0 mod 2 (CSS validity violated)"
    print("  (iii) H_X @ H_Z^T == 0 (mod 2). OK")

    # (iv) logical qubit count.
    rank_x = lg.gf2_rank(HX)
    rank_z = lg.gf2_rank(HZ)
    k = code.n - rank_x - rank_z
    print(f"  (iv)  rank(HX)={rank_x}, rank(HZ)={rank_z}, k = n - rank_x - rank_z = {k} "
          f"(expected {code.k_expected})")
    assert k == code.k_expected, f"logical count mismatch: got {k}, expected {code.k_expected}"

    # (v) logical_witness two-sidedness.
    # success case: r = H_X^T w for a random check-combination w.
    w_rand = RNG.integers(0, 2, size=lm, dtype=np.uint8)
    r_success = (HX.T @ w_rand) % 2
    outcome, witness = lg.logical_witness(HX, r_success)
    assert outcome == "success", f"expected success witness, got {outcome}"
    # verify witness reproduces r under H_X^T
    assert np.array_equal((HX.T @ witness) % 2, r_success), "success witness does not reproduce r"
    print("  (v)   success case: logical_witness returns ('success', w) with H_X^T w = r. OK")

    # failure case: r = a known logical operator, i.e. a Z-logical operator z0 with
    # H_X z0 = 0 (z0 in ker H_X) that is NOT a Z-stabilizer (not in row space of H_Z),
    # so it pairs nontrivially with at least one X-stabilizer combination via z0 itself
    # acting as the residual (r := z0). By construction z0 in ker(H_X) and <z0, z0> may
    # be 0 in general GF2, so instead we build r as a *bona fide* non-stabilizer vector:
    # take a kernel vector of H_X (a candidate logical/stabilizer generator) that is
    # provably outside the row space of H_X^T (i.e. r not in Im(H_X^T)); logical_witness
    # must then return a failure witness z with H_X z = 0 and <z, r> = 1.
    ker_basis = lg.kernel_basis(HX)
    assert ker_basis.shape[0] > 0, "expected nontrivial kernel of H_X (logical operators exist)"
    r_failure = None
    for cand in ker_basis:
        # cand in Im(H_X^T) <=> cand in row space of H_X (in_row_space transposes internally)
        if not lg.in_row_space(HX, cand):
            r_failure = cand
            break
    assert r_failure is not None, (
        "could not find a kernel vector of H_X outside Im(H_X^T) -- "
        "code may have trivial logical space, cannot construct failure test case"
    )
    outcome2, witness2 = lg.logical_witness(HX, r_failure)
    assert outcome2 == "failure", f"expected failure witness, got {outcome2}"
    assert (HX @ witness2 % 2).sum() == 0, "failure witness z must satisfy H_X z = 0"
    dotv = int(np.dot(witness2, r_failure) % 2)
    assert dotv == 1, f"failure witness must satisfy <z, r> = 1, got {dotv}"
    print("  (v)   failure case: logical_witness returns ('failure', z) with "
          "H_X z = 0 and <z, r> = 1. OK")

    print(f"  ALL CHECKS PASSED for {code.name}.")


def main() -> int:
    print(f"crosscheck.py -- seed={SEED}, jax available={st._HAVE_JAX}")
    for name, code in REGISTRY.items():
        check_code(code)
    print("\n" + "=" * 70)
    print("CROSSCHECK: ALL CODES, ALL CHECKS PASSED.")
    print("=" * 70)
    return 0


if __name__ == "__main__":
    sys.exit(main())
