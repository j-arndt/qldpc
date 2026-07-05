"""
codes.py -- Bivariate bicycle (BB) quantum LDPC code registry.

Conventions (MUST match proofs/BBCode.lean and proofs/QCCirculant.lean exactly):

  Group G = Z_l x Z_m (represented as Fin l x Fin m in Lean, (l, m) numpy shape here).
  A code is two sparse polynomials a, b given by supp(a), supp(b) subset of G.

  Sparse forward eval  (SparsePoly.mulVecS):
      (p . w)(i) = sum_{k in supp p} w(i - k)                (indices mod (l, m))

  Sparse transpose eval (SparsePoly.mulVecT):
      (p^T . w)(i) = sum_{k in supp p} w(k + i)

  Z-syndrome (detects X errors), from BBCode.lean `syndromeZ`:
      syndromeZ(e)(g) = sum_{k in supp b} e1(k+g) + sum_{k in supp a} e2(k+g)
      i.e. H_Z = [B^T | A^T]      (e = (e1, e2) is a QubitVec: two (l,m) F2 arrays)

  X-stabilizer application (`xStab`):
      xStab(w) = ( sum_{k in supp a} w(k+.) , sum_{k in supp b} w(k+.) )
      i.e. xStab(w) = H_X^T w

  X-syndrome (annihilates Z-logicals), from BBCode.lean `syndromeX`:
      syndromeX(f)(g) = sum_{k in supp a} f1(g-k) + sum_{k in supp b} f2(g-k)
      i.e. H_X = [A | B]

  All arithmetic mod 2.

Dense matrix layout: qubits are laid out in two blocks (left = block 1, right = block 2),
each block flattened from (l, m) via row-major (numpy default) order: index(i,j) = i*m + j.
H_X, H_Z : shape (l*m, 2*l*m), column blocks [left | right], each column block (l*m, l*m).

This module additionally exposes the *dense-from-convolution* construction independently
(build_HX_naive / build_HZ_naive) used by crosscheck.py as a from-scratch ground truth that
does not share code with the roll-based/circulant path.
"""

from __future__ import annotations

import dataclasses
from typing import Dict, List, Tuple

import numpy as np
import scipy.sparse as sp

Coord = Tuple[int, int]


def _mod(i: int, n: int) -> int:
    return i % n


@dataclasses.dataclass(frozen=True)
class BBCode:
    """A bivariate bicycle code given by (l, m, supp_a, supp_b).

    l, m: torus dimensions, G = Z_l x Z_m.
    supp_a, supp_b: sparse supports (list of (i, j) pairs) of polynomials a, b in F2[G].
    name, distance, k: bookkeeping (k = number of logical qubits, expected).
    """

    name: str
    l: int
    m: int
    supp_a: Tuple[Coord, ...]
    supp_b: Tuple[Coord, ...]
    n: int = dataclasses.field(init=False)
    k_expected: int = 0
    d_expected: int = 0

    def __post_init__(self):
        object.__setattr__(self, "n", 2 * self.l * self.m)

    # ---- indexing helpers -------------------------------------------------
    @property
    def group_size(self) -> int:
        return self.l * self.m

    def idx(self, i: int, j: int) -> int:
        """Row-major flatten of (l, m) -> [0, l*m)."""
        return _mod(i, self.l) * self.m + _mod(j, self.m)

    # ---- dense circulant blocks (via convolution definition) -------------
    def _circulant_block(self, supp: Tuple[Coord, ...], transpose: bool) -> np.ndarray:
        """Dense (l*m, l*m) uint8 matrix for polynomial with support `supp`.

        transpose=False: forward action, row i col j is 1 iff j = i - k for some k in supp
                          (M w)(i) = sum_k w(i-k)  =>  M[i, i-k] = 1 for k in supp.
        transpose=True:  M[i, k+i] = 1 for k in supp  (the mulVecT convention).
        """
        lm = self.group_size
        M = np.zeros((lm, lm), dtype=np.uint8)
        for i in range(self.l):
            for j in range(self.m):
                row = self.idx(i, j)
                for (ki, kj) in supp:
                    if not transpose:
                        col = self.idx(i - ki, j - kj)
                    else:
                        col = self.idx(i + ki, j + kj)
                    M[row, col] ^= 1
        return M

    def build_HX_naive(self) -> np.ndarray:
        """H_X = [A | B], from-scratch nested loops (no reuse of structured.py)."""
        A = self._circulant_block(self.supp_a, transpose=False)
        B = self._circulant_block(self.supp_b, transpose=False)
        return np.concatenate([A, B], axis=1).astype(np.uint8)

    def build_HZ_naive(self) -> np.ndarray:
        """H_Z = [B^T | A^T], from-scratch nested loops."""
        BT = self._circulant_block(self.supp_b, transpose=True)
        AT = self._circulant_block(self.supp_a, transpose=True)
        return np.concatenate([BT, AT], axis=1).astype(np.uint8)

    # ---- cached dense/sparse matrices -------------------------------------
    def HX(self) -> np.ndarray:
        return self.build_HX_naive()

    def HZ(self) -> np.ndarray:
        return self.build_HZ_naive()

    def HX_csr(self) -> sp.csr_matrix:
        return sp.csr_matrix(self.HX())

    def HZ_csr(self) -> sp.csr_matrix:
        return sp.csr_matrix(self.HZ())

    # ---- shift lists for roll-based ops -----------------------------------
    def shifts_a(self) -> List[Coord]:
        return list(self.supp_a)

    def shifts_b(self) -> List[Coord]:
        return list(self.supp_b)


# ---------------------------------------------------------------------------
# Registry: Bravyi et al., Nature 627, 2024, Table 3 bivariate-bicycle codes.
# Monomial x^i y^j <-> coordinate (i, j) in Z_l x Z_m.
# ---------------------------------------------------------------------------

CODE72 = BBCode(
    name="code72",
    l=6, m=6,
    supp_a=((3, 0), (0, 1), (0, 2)),   # a = x^3 + y + y^2
    supp_b=((0, 3), (1, 0), (2, 0)),   # b = y^3 + x + x^2
    k_expected=12, d_expected=6,
)

CODE90 = BBCode(
    name="code90",
    l=15, m=3,
    supp_a=((9, 0), (0, 1), (0, 2)),   # a = x^9 + y + y^2
    supp_b=((0, 0), (2, 0), (7, 0)),   # b = 1 + x^2 + x^7
    k_expected=8, d_expected=10,
)

CODE108 = BBCode(
    name="code108",
    l=9, m=6,
    supp_a=((3, 0), (0, 1), (0, 2)),   # a = x^3 + y + y^2
    supp_b=((0, 3), (1, 0), (2, 0)),   # b = y^3 + x + x^2
    k_expected=8, d_expected=10,
)

GROSS144 = BBCode(
    name="gross144",
    l=12, m=6,
    supp_a=((3, 0), (0, 1), (0, 2)),   # a = x^3 + y + y^2
    supp_b=((0, 3), (1, 0), (2, 0)),   # b = y^3 + x + x^2
    k_expected=12, d_expected=12,
)

CODE288 = BBCode(
    name="code288",
    l=12, m=12,
    supp_a=((3, 0), (0, 2), (0, 7)),   # a = x^3 + y^2 + y^7
    supp_b=((0, 3), (1, 0), (2, 0)),   # b = y^3 + x + x^2
    k_expected=12, d_expected=18,
)

REGISTRY: Dict[str, BBCode] = {
    c.name: c for c in [CODE72, CODE90, CODE108, GROSS144, CODE288]
}


def get_code(name: str) -> BBCode:
    if name not in REGISTRY:
        raise KeyError(f"Unknown code '{name}'. Known: {sorted(REGISTRY)}")
    return REGISTRY[name]


if __name__ == "__main__":
    for name, c in REGISTRY.items():
        HX, HZ = c.HX(), c.HZ()
        print(f"{name}: l={c.l} m={c.m} n={c.n} HX.shape={HX.shape} "
              f"HX_rowweight={HX.sum(axis=1).max()} "
              f"commute_ok={np.all((HX @ HZ.T) % 2 == 0)}")
