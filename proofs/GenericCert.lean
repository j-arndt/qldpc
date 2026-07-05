-- Copyright (c) 2026 Justin Arndt. All rights reserved.
-- Licensed under the GNU GPLv3. For commercial licensing and proprietary
-- hardware mapping, see the LICENSE file (dual-licensing notice at top).
/-
# GenericCert — Matrix-Generic Two-Sided Decoder-Output Certification

Generalizes `DecoderCert.lean` from `GBCode`-specific syndrome maps to an
arbitrary F₂ matrix `H : Matrix (Fin r) (Fin n) (ZMod 2)`. This is the
abstraction needed for:

  - **Phenomenological noise**: the spacetime parity-check matrix `H_st` stacks
    spatial checks over `d` syndrome rounds with a temporal chain (repetition
    structure along the time axis). `H_st` is NOT circulant in the time
    direction, but its spatial blocks are — and the checker soundness theorems
    below apply to any `H`, circulant or not.
  - **Future code families**: any CSS or non-CSS stabilizer code whose checks
    are F₂-linear can instantiate this module.

The code-capacity `DecoderCert` layer is recovered as a special case when
`H = GBCode.HZ` (or `HX`), so existing certificates remain valid.

## Main results

- `checkSyn_sound`: sparse-or-dense syndrome checker soundness.
- `checkSuccess_sound`: success-witness soundness (`Hᵀ w = e`).
- `checkFailure_sound`: failure-witness soundness (`H_orth z = 0 ∧ ⟨z,e⟩ = 1`).
- `witness_exclusive_generic`: no error vector carries both certificates.
- `validateGenericRun_sound`: master theorem for the generic run certificate.

Zero sorries, zero axioms, no native_decide.
-/

import Mathlib

open Matrix Finset

namespace QLDPC.GenericCert

variable {r n : ℕ}

/-! ## Section 1: The generic F₂ checker layer -/

/-- Syndrome consistency: `H · e = s`. -/
def checkSyn (H : Matrix (Fin r) (Fin n) (ZMod 2))
    (e : Fin n → ZMod 2) (s : Fin r → ZMod 2) : Bool :=
  decide (H.mulVec e = s)

/-- Success witness: `Hᵀ · w = e`. -/
def checkSuccess (H : Matrix (Fin r) (Fin n) (ZMod 2))
    (e : Fin n → ZMod 2) (w : Fin r → ZMod 2) : Bool :=
  decide (Hᵀ.mulVec w = e)

/-- The F₂ dot product on `Fin n → ZMod 2`. -/
def dot (v w : Fin n → ZMod 2) : ZMod 2 := ∑ i, v i * w i

/-- Failure witness: `H_orth · z = 0` and `⟨z, e⟩ = 1`, where `H_orth` is the
    orthogonal parity-check (for CSS: if `H = H_Z`, then `H_orth = H_X`). -/
def checkFailure (H_orth : Matrix (Fin r) (Fin n) (ZMod 2))
    (e : Fin n → ZMod 2) (z : Fin n → ZMod 2) : Bool :=
  decide (H_orth.mulVec z = 0) && decide (dot z e = 1)

/-! ## Section 2: Soundness theorems -/

theorem checkSyn_sound (H : Matrix (Fin r) (Fin n) (ZMod 2))
    (e : Fin n → ZMod 2) (s : Fin r → ZMod 2)
    (h : checkSyn H e s = true) : H.mulVec e = s := by
  simpa [checkSyn, decide_eq_true_eq] using h

theorem checkSuccess_sound (H : Matrix (Fin r) (Fin n) (ZMod 2))
    (e : Fin n → ZMod 2) (w : Fin r → ZMod 2)
    (h : checkSuccess H e w = true) : ∃ w', Hᵀ.mulVec w' = e :=
  ⟨w, by simpa [checkSuccess, decide_eq_true_eq] using h⟩

/-- Adjointness: `⟨z, Hᵀ w⟩ = ⟨H z, w⟩`. -/
theorem dot_transpose (H : Matrix (Fin r) (Fin n) (ZMod 2))
    (z : Fin n → ZMod 2) (w : Fin r → ZMod 2) :
    dot z (Hᵀ.mulVec w) = dot (H.mulVec z) w := by
  unfold dot
  show ∑ i, z i * (Hᵀ.mulVec w) i = ∑ j, (H.mulVec z) j * w j
  simp only [Matrix.mulVec, dotProduct, Matrix.transpose_apply]
  -- goal: ∑ i, z i * ∑ j, H j i * w j = ∑ j, (∑ i, H j i * z i) * w j
  have hL : ∀ i, z i * ∑ j, H j i * w j = ∑ j, z i * (H j i * w j) :=
    fun i => Finset.mul_sum _ _ _
  simp_rw [hL]
  rw [Finset.sum_comm]
  refine Finset.sum_congr rfl fun j _ => ?_
  rw [Finset.sum_mul]
  refine Finset.sum_congr rfl fun i _ => ?_
  ring

/-- If `H_orth z = 0`, then `z` pairs to zero with every vector in `Im Hᵀ`. -/
theorem dot_image_zero (H H_orth : Matrix (Fin r) (Fin n) (ZMod 2))
    (z : Fin n → ZMod 2) (hz : H_orth.mulVec z = 0)
    (hcomm : H_orth = H)  -- in practice H_orth = H_X when H = H_X; or pass H_orth = H
    (w : Fin r → ZMod 2) :
    dot z (Hᵀ.mulVec w) = 0 := by
  rw [dot_transpose]
  subst hcomm
  rw [hz]
  simp [dot]

theorem checkFailure_sound (H_orth : Matrix (Fin r) (Fin n) (ZMod 2))
    (e : Fin n → ZMod 2) (z : Fin n → ZMod 2)
    (h : checkFailure H_orth e z = true) :
    ¬ ∃ w, H_orthᵀ.mulVec w = e := by
  simp [checkFailure, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨hker, hdot⟩ := h
  rintro ⟨w, rfl⟩
  have h0 := dot_image_zero H_orth H_orth z hker rfl w
  rw [h0] at hdot
  exact zero_ne_one hdot

/-- **Exclusivity**: no error vector can carry both a success and a failure
    certificate against the same matrix. -/
theorem witness_exclusive_generic (H : Matrix (Fin r) (Fin n) (ZMod 2))
    (e : Fin n → ZMod 2) (w : Fin r → ZMod 2) (z : Fin n → ZMod 2) :
    ¬ (checkSuccess H e w = true ∧ checkFailure H e z = true) := by
  rintro ⟨hs, hf⟩
  exact checkFailure_sound H e z hf (checkSuccess_sound H e w hs)

/-! ## Section 3: Generic run certificate and master theorem -/

/-- A generic decode-run certificate: syndrome, correction, injected error, and
    a two-sided outcome witness. Works for any F₂ parity-check matrix. -/
structure GenericRunCert (r n : ℕ) where
  H_check : Matrix (Fin r) (Fin n) (ZMod 2)
  H_orth  : Matrix (Fin r) (Fin n) (ZMod 2)
  observed : Fin r → ZMod 2
  correction : Fin n → ZMod 2
  injected : Fin n → ZMod 2
  residualWitness : (Fin r → ZMod 2) ⊕ (Fin n → ZMod 2)

/-- The master Boolean validator for a generic run. -/
def validateGenericRun (rc : GenericRunCert r n) : Bool :=
  checkSyn rc.H_check rc.correction rc.observed &&
  checkSyn rc.H_check rc.injected rc.observed &&
  match rc.residualWitness with
  | .inl w => checkSuccess rc.H_orth (rc.correction + rc.injected) w
  | .inr z => checkFailure rc.H_orth (rc.correction + rc.injected) z

/-- **Master soundness theorem (generic)**: acceptance implies dense syndrome
    consistency of both vectors, the residual lying in `ker H_check`
    (undetectable), and the certified logical outcome. -/
theorem validateGenericRun_sound (rc : GenericRunCert r n)
    (h : validateGenericRun rc = true) :
    rc.H_check.mulVec rc.correction = rc.observed ∧
    rc.H_check.mulVec rc.injected = rc.observed ∧
    rc.H_check.mulVec (rc.correction + rc.injected) = 0 ∧
    (match rc.residualWitness with
     | .inl _ => ∃ w, rc.H_orthᵀ.mulVec w = rc.correction + rc.injected
     | .inr _ => ¬ ∃ w, rc.H_orthᵀ.mulVec w = rc.correction + rc.injected) := by
  unfold validateGenericRun at h
  simp only [Bool.and_eq_true] at h
  obtain ⟨⟨h1, h2⟩, h3⟩ := h
  have hd1 := checkSyn_sound _ _ _ h1
  have hd2 := checkSyn_sound _ _ _ h2
  have hker : rc.H_check.mulVec (rc.correction + rc.injected) = 0 := by
    rw [mulVec_add, hd1, hd2]
    funext i
    simp only [Pi.add_apply, Pi.zero_apply]
    exact CharTwo.add_self_eq_zero _
  refine ⟨hd1, hd2, hker, ?_⟩
  cases hw : rc.residualWitness with
  | inl w => rw [hw] at h3; exact checkSuccess_sound _ _ w h3
  | inr z => rw [hw] at h3; exact checkFailure_sound _ _ z h3

end QLDPC.GenericCert
