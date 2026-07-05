"""
logical.py -- GF(2) linear algebra (numpy uint8) for BB codes: row reduction, rank,
exact solving of H_X^T w = r (or reporting unsolvable), kernel basis of H_X, and the
two-sided logical_witness(H_X, r) function used by the decoder-outcome certificate
layer (mirrors proofs/DecoderCert.lean's success/failure witness split).

All matrices are numpy uint8 arrays; all arithmetic is mod 2 (XOR for addition, AND
for multiplication). Row reduction is done via Gauss-Jordan elimination over GF(2)
using bitwise XOR row operations (vectorized per pivot row).
"""

from __future__ import annotations

from typing import Optional, Tuple

import numpy as np


def gf2_row_reduce(M: np.ndarray) -> Tuple[np.ndarray, list]:
    """Gauss-Jordan row reduction of M (rows x cols) over GF(2), in place on a copy.

    Returns (R, pivot_cols) where R is the row-reduced echelon form and pivot_cols is
    the list of pivot column indices, one per nonzero row of R (len(pivot_cols) = rank).
    """
    R = M.copy().astype(np.uint8) & 1
    n_rows, n_cols = R.shape
    pivot_row = 0
    pivot_cols = []
    for col in range(n_cols):
        if pivot_row >= n_rows:
            break
        # find a row with a 1 in this column, at or below pivot_row
        nz = np.nonzero(R[pivot_row:, col])[0]
        if nz.size == 0:
            continue
        sel = pivot_row + nz[0]
        if sel != pivot_row:
            R[[pivot_row, sel]] = R[[sel, pivot_row]]
        # eliminate this column from all other rows
        mask = R[:, col].astype(bool)
        mask[pivot_row] = False
        R[mask] ^= R[pivot_row]
        pivot_cols.append(col)
        pivot_row += 1
    return R, pivot_cols


def gf2_rank(M: np.ndarray) -> int:
    """Rank of M over GF(2)."""
    if M.size == 0:
        return 0
    _, pivots = gf2_row_reduce(M)
    return len(pivots)


def gf2_solve(A: np.ndarray, b: np.ndarray) -> Optional[np.ndarray]:
    """Solve A x = b over GF(2) exactly (no least-squares). A: (r, c), b: (r,).

    Returns a particular solution x (shape (c,), uint8) if the system is consistent,
    else None. Uses augmented-matrix Gauss-Jordan elimination; robust for the sizes
    used here (r, c up to a few hundred).
    """
    A = A.astype(np.uint8) & 1
    b = (np.asarray(b).astype(np.uint8) & 1).reshape(-1)
    r, c = A.shape
    assert b.shape[0] == r, f"shape mismatch: A is {A.shape}, b is {b.shape}"

    aug = np.concatenate([A, b.reshape(-1, 1)], axis=1)
    R, pivot_cols = gf2_row_reduce(aug)

    # inconsistency check: a fully-zero row in the A-part with a 1 in the augmented col
    for row_idx in range(R.shape[0]):
        if row_idx >= len(pivot_cols) or (pivot_cols and pivot_cols[row_idx] == c):
            # this row's pivot (if any) is in the augmented column itself -> 0 = 1
            pass
    # Simpler robust check: any row with all-zero in A-columns but 1 in last column.
    zero_A_rows = ~R[:, :c].any(axis=1)
    inconsistent = np.any(zero_A_rows & (R[:, c] == 1))
    if inconsistent:
        return None

    x = np.zeros(c, dtype=np.uint8)
    for i, col in enumerate(pivot_cols):
        if col == c:
            continue  # shouldn't happen given the inconsistency check above
        x[col] = R[i, c]
    return x


def kernel_basis(M: np.ndarray) -> np.ndarray:
    """Basis of the kernel (null space) of M over GF(2): all x with M x = 0.

    Returns an array of shape (dim_ker, n_cols), each row a basis vector.
    Standard method: row-reduce M to get pivot/free columns; for each free column,
    build a basis vector by back-substitution.
    """
    M = M.astype(np.uint8) & 1
    n_rows, n_cols = M.shape
    R, pivot_cols = gf2_row_reduce(M)
    pivot_set = set(pivot_cols)
    free_cols = [c for c in range(n_cols) if c not in pivot_set]
    rank = len(pivot_cols)

    basis = []
    for free_col in free_cols:
        x = np.zeros(n_cols, dtype=np.uint8)
        x[free_col] = 1
        # back-substitute: for each pivot row i with pivot column pivot_cols[i],
        # x[pivot_cols[i]] = sum over non-pivot cols c' (with R[i, c']=1) of x[c']
        # Since R is in reduced row-echelon form, R[i, pivot_cols[i]] = 1 and the
        # row equation is: x[pivot_cols[i]] + sum_{c' != pivot_cols[i]} R[i,c']*x[c'] = 0
        for i in range(rank):
            pc = pivot_cols[i]
            row = R[i]
            # contribution from all set free/other columns already fixed in x, excluding pc
            s = 0
            nz_cols = np.nonzero(row)[0]
            for c2 in nz_cols:
                if c2 == pc:
                    continue
                s ^= int(row[c2]) & int(x[c2])
            x[pc] = s
        basis.append(x)

    if not basis:
        return np.zeros((0, n_cols), dtype=np.uint8)
    return np.stack(basis, axis=0)


def in_row_space(A: np.ndarray, v: np.ndarray) -> bool:
    """True iff v is in the row space of A over GF(2), i.e. v = w A for some w,
    equivalently v^T = A^T w, i.e. solvable as A^T x = v."""
    sol = gf2_solve(A.T, v)
    return sol is not None


def logical_witness(HX: np.ndarray, r: np.ndarray):
    """Two-sided decoder-outcome witness, mirroring DecoderCert.lean's
    checkSuccessWitness / checkFailureWitness split.

    Given H_X (shape (n_checks, n_qubits)) and a residual vector r (shape (n_qubits,)),
    determine whether r is an X-stabilizer, i.e. r = H_X^T w for some w:

      - if solvable: return ('success', w) with H_X^T w = r  (mod 2).
      - if not solvable: return ('failure', z) with z in ker(H_X) and <z, r> = 1 mod 2.
        Existence is guaranteed whenever r is NOT in Im(H_X^T): Im(H_X^T)^perp = ker(H_X)
        (standard GF(2) orthogonal-complement duality for the row space / null space of a
        matrix and its transpose), so if r is outside Im(H_X^T) there must be some z in
        ker(H_X) with <z, r> = 1 -- we search the kernel basis (and, if no single basis
        vector works, combinations of the basis) for such a z, and assert one is found.

    Returns (outcome: str, witness: np.ndarray[uint8]).
    """
    r = np.asarray(r).astype(np.uint8).reshape(-1)
    w = gf2_solve(HX.T, r)
    if w is not None:
        return "success", w

    # Unsolvable: find z in ker(H_X) with <z, r> = 1.
    K = kernel_basis(HX)
    assert K.shape[0] > 0, (
        "logical_witness: system H_X^T w = r is unsolvable but ker(H_X) is trivial -- "
        "this contradicts GF(2) row/null-space duality and should be impossible"
    )
    dots = (K.astype(np.uint8) @ r.astype(np.uint8)) % 2  # shape (dim_ker,)
    nz = np.nonzero(dots)[0]
    if nz.size > 0:
        z = K[nz[0]].copy()
        return "failure", z

    # None of the individual basis vectors pair to 1 with r directly: since r is not
    # in Im(H_X^T) = ker(H_X)^perp, *some* linear combination of the kernel basis must
    # pair to 1 (the pairing z -> <z, r> restricted to ker(H_X) is a nonzero linear
    # functional on ker(H_X) whenever r is outside its perp -- if it were the zero
    # functional, r would perp all of ker(H_X), i.e. r in ker(H_X)^perp = Im(H_X^T),
    # contradicting unsolvability). Search combinations exhaustively for the (typically
    # small) kernel dimension.
    dim = K.shape[0]
    assert dim <= 24, f"kernel dimension {dim} too large for exhaustive combination search"
    for mask in range(1, 1 << dim):
        coeffs = np.array([(mask >> i) & 1 for i in range(dim)], dtype=np.uint8)
        z = (coeffs @ K) % 2
        if int(np.dot(z, r)) % 2 == 1:
            return "failure", z.astype(np.uint8)

    raise AssertionError(
        "logical_witness: unsolvable system but no kernel combination pairs to 1 with r "
        "-- violates GF(2) duality (ker(H_X) = Im(H_X^T)^perp); this should be unreachable"
    )


def compute_k(HX: np.ndarray, HZ: np.ndarray, n: int) -> int:
    """k = n - rank(H_X) - rank(H_Z)."""
    return n - gf2_rank(HX) - gf2_rank(HZ)
