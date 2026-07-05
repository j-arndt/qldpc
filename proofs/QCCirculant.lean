/-
# QCCirculant — Circulant Algebra Bridge for Quasi-Cyclic QLDPC Verification

IRONCLAD-QLDPC extension, file F1. 2026-07-05.

## Purpose

Bivariate bicycle (BB) and generalized-bicycle quantum LDPC codes have parity-check
matrices built from circulant blocks over the group algebra F₂[G] with G a finite
abelian group (G = Fin ℓ × Fin m for BB codes). This file provides the verified
bridge between three representations of the same linear action:

1. **Dense**: `Matrix.circulant v` (mathlib's circulant matrix, generic over any
   `AddCommGroup` index — bivariate structure is free).
2. **Convolutional**: `cyclicConv` — the group-algebra product action.
3. **Sparse**: `SparsePoly.mulVecS` / `mulVecT` — evaluation summing only over the
   polynomial's support (row weight), the form a fast checker actually computes.

## Main results

- `circulant_mulVec` : dense = convolutional.
- `SparsePoly.mulVecS_eq_mulVec` (**T1**): sparse forward evaluation = dense `mulVec`.
- `SparsePoly.mulVecT_eq_mulVec` (**T1ᵀ**): sparse transpose evaluation = `Mᵀ.mulVec`.
- `dotF2_mulVecT_left` (**adjointness**): ⟪v, pᵀ·w⟫ = ⟪p·v, w⟫ over F₂ — the lemma
  powering the two-sided (success/failure) decoder-outcome witness theorems.

T1/T1ᵀ are what make an O(row-weight)-per-bit syndrome check *sound*: the cheap sum
over the support provably equals the full matrix-vector product. We build on (and
cite) mathlib's `Matrix.circulant` API (`circulant_mul`, `circulant_mul_comm`); we
do not re-derive the circulant algebra itself.

## Claims discipline

No runtime-complexity claims are made as theorems. These are semantic-equality
results; wall-clock behavior is measured empirically outside the proof layer.
Zero sorries, zero axioms, no native_decide.
-/

import Mathlib

open Matrix Finset

namespace QCCirculant

variable {G : Type*} [AddCommGroup G] [Fintype G] [DecidableEq G]

/-! ## Section 1: Cyclic convolution and the dense bridge -/

/-- Cyclic convolution over an additive-group index: `(v ⋆ w) i = ∑ j, v (i - j) * w j`.
    This is the action of the group-algebra element `v` on `w`. -/
def cyclicConv {R : Type*} [NonUnitalNonAssocSemiring R] (v w : G → R) : G → R :=
  fun i => ∑ j, v (i - j) * w j

omit [DecidableEq G] in
/-- **Dense = convolutional**: the circulant matrix action is cyclic convolution. -/
theorem circulant_mulVec {R : Type*} [NonUnitalNonAssocSemiring R] (v w : G → R) :
    (Matrix.circulant v).mulVec w = cyclicConv v w := rfl

/-! ## Section 2: Sparse polynomials over F₂

Over F₂ a group-algebra element is exactly its support set. BB codes use
polynomials of support size 3 (row weight 6 per check across both blocks). -/

/-- A sparse F₂ group-algebra element, represented by its support. -/
structure SparsePoly (G : Type*) where
  support : Finset G

namespace SparsePoly

variable (p : SparsePoly G)

/-- The dense F₂ coefficient vector of a sparse polynomial. -/
def toVec : G → ZMod 2 := fun g => if g ∈ p.support then 1 else 0

/-- Sparse forward evaluation: `(p · w) i = ∑_{k ∈ supp p} w (i - k)`.
    Cost per output bit: |support| additions — independent of |G|. -/
def mulVecS (w : G → ZMod 2) : G → ZMod 2 :=
  fun i => ∑ k ∈ p.support, w (i - k)

/-- Sparse transpose evaluation: `(pᵀ · w) i = ∑_{k ∈ supp p} w (k + i)`. -/
def mulVecT (w : G → ZMod 2) : G → ZMod 2 :=
  fun i => ∑ k ∈ p.support, w (k + i)

/-- Pointwise form of the convolution against a sparse polynomial's vector. -/
theorem cyclicConv_toVec (w : G → ZMod 2) (i : G) :
    cyclicConv p.toVec w i = ∑ k ∈ p.support, w (i - k) := by
  unfold cyclicConv
  calc ∑ j, p.toVec (i - j) * w j
      = ∑ j, p.toVec ((Equiv.subLeft i) j) * w (i - (Equiv.subLeft i) j) := by
        refine Finset.sum_congr rfl fun j _ => ?_
        simp [Equiv.subLeft_apply, sub_sub_cancel]
    _ = ∑ k, p.toVec k * w (i - k) :=
        Equiv.sum_comp (Equiv.subLeft i) (fun k => p.toVec k * w (i - k))
    _ = ∑ k ∈ p.support, w (i - k) := by
        simp [toVec, ite_mul, Finset.sum_ite_mem]

/-- **T1 (sparse-check soundness, forward)**: sparse evaluation over the support
    equals the dense circulant matrix-vector product. This theorem is what makes
    an O(row-weight)-per-bit syndrome check trustworthy. -/
theorem mulVecS_eq_mulVec (w : G → ZMod 2) :
    p.mulVecS w = (Matrix.circulant p.toVec).mulVec w := by
  funext i
  rw [circulant_mulVec]
  exact (p.cyclicConv_toVec w i).symm

/-- **T1ᵀ (sparse-check soundness, transpose)**: sparse transpose evaluation equals
    the dense transposed circulant matrix-vector product. Needed to apply stabilizer
    combinations (`H_Xᵀ w`) in witness checking. -/
theorem mulVecT_eq_mulVec (w : G → ZMod 2) :
    p.mulVecT w = (Matrix.circulant p.toVec)ᵀ.mulVec w := by
  funext i
  show ∑ k ∈ p.support, w (k + i) = ∑ j, (Matrix.circulant p.toVec)ᵀ i j * w j
  have hT : ∀ j, (Matrix.circulant p.toVec)ᵀ i j = p.toVec (j - i) := by
    intro j
    simp [Matrix.transpose_apply, Matrix.circulant_apply]
  calc ∑ k ∈ p.support, w (k + i)
      = ∑ k, p.toVec k * w (k + i) := by
        simp [toVec, ite_mul, Finset.sum_ite_mem]
    _ = ∑ k, p.toVec ((Equiv.addRight i) k - i) * w ((Equiv.addRight i) k) := by
        refine Finset.sum_congr rfl fun k _ => ?_
        simp [Equiv.coe_addRight, add_sub_cancel_right]
    _ = ∑ j, p.toVec (j - i) * w j :=
        Equiv.sum_comp (Equiv.addRight i) (fun j => p.toVec (j - i) * w j)
    _ = ∑ j, (Matrix.circulant p.toVec)ᵀ i j * w j := by
        refine Finset.sum_congr rfl fun j _ => ?_
        rw [hT j]

end SparsePoly

/-! ## Section 3: The F₂ bilinear form and adjointness

The symplectic-pairing arguments for decoder-outcome witnesses reduce to this:
a Z-type witness annihilated by the X-checks pairs to zero with every
X-stabilizer. The kernel of that argument is the adjointness lemma below. -/

/-- The F₂ dot product (bilinear pairing) on `G → ZMod 2`. -/
def dotF2 (v w : G → ZMod 2) : ZMod 2 := ∑ g, v g * w g

omit [AddCommGroup G] [DecidableEq G] in
theorem dotF2_comm (v w : G → ZMod 2) : dotF2 v w = dotF2 w v := by
  unfold dotF2
  exact Finset.sum_congr rfl fun g _ => mul_comm _ _

omit [DecidableEq G] in
/-- **Adjointness**: ⟪v, pᵀ·w⟫ = ⟪p·v, w⟫. Sparse transpose evaluation is adjoint
    to sparse forward evaluation with respect to the F₂ pairing. -/
theorem dotF2_mulVecT_left (p : SparsePoly G) (v w : G → ZMod 2) :
    dotF2 v (p.mulVecT w) = dotF2 (p.mulVecS v) w := by
  unfold dotF2 SparsePoly.mulVecT SparsePoly.mulVecS
  calc ∑ i, v i * ∑ k ∈ p.support, w (k + i)
      = ∑ i, ∑ k ∈ p.support, v i * w (k + i) := by
        refine Finset.sum_congr rfl fun i _ => Finset.mul_sum _ _ _
    _ = ∑ k ∈ p.support, ∑ i, v i * w (k + i) := Finset.sum_comm
    _ = ∑ k ∈ p.support, ∑ j, v (j - k) * w j := by
        refine Finset.sum_congr rfl fun k _ => ?_
        calc ∑ i, v i * w (k + i)
            = ∑ i, v ((Equiv.addLeft k) i - k) * w ((Equiv.addLeft k) i) := by
              refine Finset.sum_congr rfl fun i _ => ?_
              simp [Equiv.coe_addLeft, add_sub_cancel_left]
          _ = ∑ j, v (j - k) * w j :=
              Equiv.sum_comp (Equiv.addLeft k) (fun j => v (j - k) * w j)
    _ = ∑ j, ∑ k ∈ p.support, v (j - k) * w j := Finset.sum_comm
    _ = ∑ j, (∑ k ∈ p.support, v (j - k)) * w j := by
        refine Finset.sum_congr rfl fun j _ => (Finset.sum_mul _ _ _).symm

omit [AddCommGroup G] [DecidableEq G] in
theorem dotF2_zero_left (w : G → ZMod 2) : dotF2 (0 : G → ZMod 2) w = 0 := by
  unfold dotF2
  simp

omit [AddCommGroup G] [DecidableEq G] in
theorem dotF2_add_left (v₁ v₂ w : G → ZMod 2) :
    dotF2 (v₁ + v₂) w = dotF2 v₁ w + dotF2 v₂ w := by
  unfold dotF2
  rw [← Finset.sum_add_distrib]
  refine Finset.sum_congr rfl fun g _ => ?_
  simp [add_mul]

/-! ## Section 4: Translation equivariance

The group-theoretic content behind "block-diagonalizability" of quasi-cyclic
parity checks: sparse evaluation commutes with the translation action of G.
This extends the base repo's equivariance kernel (couplings commuting with
graph automorphisms) to the QLDPC setting, where the automorphisms are the
|G| qubit translations of the torus. -/

/-- Translation action of `G` on F₂ vectors: `(translate h f) g = f (g - h)`. -/
def translate (h : G) (f : G → ZMod 2) : G → ZMod 2 := fun g => f (g - h)

omit [Fintype G] [DecidableEq G] in
/-- **T3 (forward)**: sparse forward evaluation is translation-equivariant. -/
theorem SparsePoly.mulVecS_translate (p : SparsePoly G) (h : G) (f : G → ZMod 2) :
    p.mulVecS (translate h f) = translate h (p.mulVecS f) := by
  funext i
  show ∑ k ∈ p.support, f (i - k - h) = ∑ k ∈ p.support, f (i - h - k)
  refine Finset.sum_congr rfl fun k _ => ?_
  congr 1
  abel

omit [Fintype G] [DecidableEq G] in
/-- **T3 (transpose)**: sparse transpose evaluation is translation-equivariant. -/
theorem SparsePoly.mulVecT_translate (p : SparsePoly G) (h : G) (f : G → ZMod 2) :
    p.mulVecT (translate h f) = translate h (p.mulVecT f) := by
  funext i
  show ∑ k ∈ p.support, f (k + i - h) = ∑ k ∈ p.support, f (k + (i - h))
  refine Finset.sum_congr rfl fun k _ => ?_
  congr 1
  abel

end QCCirculant
