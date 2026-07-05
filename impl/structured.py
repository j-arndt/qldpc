"""
structured.py -- roll-based structured implementations of the BB syndrome/stabilizer
maps, matching proofs/BBCode.lean exactly (see codes.py docstring for the convention
recap). Provides both:
  - JAX (jnp.roll) implementations, batched over a leading batch axis, jit-friendly.
  - Pure-numpy equivalents (np.roll) for baseline comparison / environments without JAX.

Shift convention (critical for correctness):
  numpy/jax `roll(w, shift=(si, sj), axis=(0,1))` computes:
      rolled[i, j] = w[(i - si) mod l, (j - sj) mod m]

  mulVecS (forward): (p . w)(i) = sum_{k in supp p} w(i - k)
      => for each k=(ki,kj) in supp, we need w[i - ki, j - kj] at output index (i,j)
      => that is exactly roll(w, shift=(ki, kj)) evaluated at (i,j).
      => mulVecS(p, w) = sum_{k in supp p} roll(w, shift=k)

  mulVecT (transpose): (p^T . w)(i) = sum_{k in supp p} w(k + i)
      => output(i,j) = w[i+ki, j+kj] = w[(i - (-ki)) , (j - (-kj))]
      => that is roll(w, shift=(-ki, -kj)) evaluated at (i,j).
      => mulVecT(p, w) = sum_{k in supp p} roll(w, shift=(-k))

These two identities are exercised by crosscheck.py against the from-scratch dense
matrices in codes.py and against scipy CSR matvecs.
"""

from __future__ import annotations

from functools import partial
from typing import List, Tuple

import numpy as np

try:
    import jax
    import jax.numpy as jnp
    _HAVE_JAX = True
except Exception:  # pragma: no cover
    _HAVE_JAX = False

Coord = Tuple[int, int]


# ---------------------------------------------------------------------------
# Pure numpy (batched, leading axis 0 = batch, shape (B, l, m))
# ---------------------------------------------------------------------------

def np_mulVecS(supp: List[Coord], w: np.ndarray) -> np.ndarray:
    """(p . w)(i) = sum_{k in supp} w(i - k). w: (..., l, m) -> same shape."""
    out = np.zeros_like(w)
    for (ki, kj) in supp:
        out ^= np.roll(w, shift=(ki, kj), axis=(-2, -1))
    return out


def np_mulVecT(supp: List[Coord], w: np.ndarray) -> np.ndarray:
    """(p^T . w)(i) = sum_{k in supp} w(k + i)."""
    out = np.zeros_like(w)
    for (ki, kj) in supp:
        out ^= np.roll(w, shift=(-ki, -kj), axis=(-2, -1))
    return out


def np_syndromeZ(code, e1: np.ndarray, e2: np.ndarray) -> np.ndarray:
    """syndromeZ(e)(g) = sum_{k in supp b} e1(k+g) + sum_{k in supp a} e2(k+g)
    i.e. H_Z = [B^T | A^T]. e1, e2: (..., l, m) uint8 arrays -> (..., l, m)."""
    return np_mulVecT(code.supp_b, e1) ^ np_mulVecT(code.supp_a, e2)


def np_syndromeX(code, f1: np.ndarray, f2: np.ndarray) -> np.ndarray:
    """syndromeX(f)(g) = sum_{k in supp a} f1(g-k) + sum_{k in supp b} f2(g-k)
    i.e. H_X = [A | B]."""
    return np_mulVecS(code.supp_a, f1) ^ np_mulVecS(code.supp_b, f2)


def np_xStab(code, w: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    """xStab(w) = ( sum_{k in supp a} w(k+.) , sum_{k in supp b} w(k+.) ) = H_X^T w."""
    return np_mulVecT(code.supp_a, w), np_mulVecT(code.supp_b, w)


def np_zStab(code, v: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    """zStab(v) = ( sum_{k in supp b} v(.-k) , sum_{k in supp a} v(.-k) ) = H_Z^T v."""
    return np_mulVecS(code.supp_b, v), np_mulVecS(code.supp_a, v)


# ---------------------------------------------------------------------------
# JAX (jit-friendly). Supports are baked in as static python lists (traced through
# jnp.roll with static shift args) via functools.partial + jax.jit(static_argnums)
# by capturing them in a closure factory per-code, so codes with different supports
# each get their own compiled function (cached).
# ---------------------------------------------------------------------------

if _HAVE_JAX:

    def _jnp_mulVecS(supp: Tuple[Coord, ...], w):
        out = jnp.zeros_like(w)
        for (ki, kj) in supp:
            out = out ^ jnp.roll(w, shift=(ki, kj), axis=(-2, -1))
        return out

    def _jnp_mulVecT(supp: Tuple[Coord, ...], w):
        out = jnp.zeros_like(w)
        for (ki, kj) in supp:
            out = out ^ jnp.roll(w, shift=(-ki, -kj), axis=(-2, -1))
        return out

    def make_jit_syndromeZ(code):
        supp_a, supp_b = tuple(code.supp_a), tuple(code.supp_b)

        @jax.jit
        def _fn(e1, e2):
            return _jnp_mulVecT(supp_b, e1) ^ _jnp_mulVecT(supp_a, e2)

        return _fn

    def make_jit_syndromeX(code):
        supp_a, supp_b = tuple(code.supp_a), tuple(code.supp_b)

        @jax.jit
        def _fn(f1, f2):
            return _jnp_mulVecS(supp_a, f1) ^ _jnp_mulVecS(supp_b, f2)

        return _fn

    def make_jit_xStab(code):
        supp_a, supp_b = tuple(code.supp_a), tuple(code.supp_b)

        @jax.jit
        def _fn(w):
            return _jnp_mulVecT(supp_a, w), _jnp_mulVecT(supp_b, w)

        return _fn

    def make_jit_zStab(code):
        supp_a, supp_b = tuple(code.supp_a), tuple(code.supp_b)

        @jax.jit
        def _fn(v):
            return _jnp_mulVecS(supp_b, v), _jnp_mulVecS(supp_a, v)

        return _fn


# ---------------------------------------------------------------------------
# Flatten/unflatten helpers shared with logical.py / decoder.py: convert between
# the (l, m) torus array representation and the flat length-(l*m) or length-n vector
# representation used by the dense H_X / H_Z matrices in codes.py.
# ---------------------------------------------------------------------------

def flatten_lm(arr: np.ndarray) -> np.ndarray:
    """(..., l, m) uint8 -> (..., l*m) row-major, matching codes.BBCode.idx."""
    shape = arr.shape
    return arr.reshape(shape[:-2] + (shape[-2] * shape[-1],))


def unflatten_lm(vec: np.ndarray, l: int, m: int) -> np.ndarray:
    shape = vec.shape
    return vec.reshape(shape[:-1] + (l, m))


def flatten_qubitvec(f1: np.ndarray, f2: np.ndarray) -> np.ndarray:
    """(f1, f2), each (..., l, m) -> (..., 2*l*m), matching H_X/H_Z column layout
    [left block | right block]."""
    return np.concatenate([flatten_lm(f1), flatten_lm(f2)], axis=-1)


def unflatten_qubitvec(vec: np.ndarray, l: int, m: int) -> Tuple[np.ndarray, np.ndarray]:
    lm = l * m
    f1, f2 = vec[..., :lm], vec[..., lm:]
    return unflatten_lm(f1, l, m), unflatten_lm(f2, l, m)
