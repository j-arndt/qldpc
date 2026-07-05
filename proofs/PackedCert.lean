-- Copyright (c) 2026 Justin Arndt. All rights reserved.
-- Licensed under the GNU GPLv3. For commercial licensing and proprietary
-- hardware mapping, see the LICENSE file (dual-licensing notice at top).
/-
# PackedCert — Stage A: Kernel-Fast Packed Certificates

IRONCLAD-QLDPC Stage A (see ROADMAP.md). 2026-07-05.

## Purpose

The `decide`-based certificates in `DecoderCert.lean` are sound but slow (~40 s):
the kernel walks `Finset` sums term by term. This file re-expresses the run data
as `Nat` bitmasks — bit `i*m + j` of the mask is the F₂ value at torus point
`(i, j)` — and the checkers as `Nat` bitwise arithmetic, which Lean's kernel
evaluates natively via GMP. The soundness story is unchanged because every packed
operation carries an **unpacking theorem** identifying it with the semantic
definitions of `QCCirculant`/`BBCode`/`DecoderCert`; the master theorem transfers
`validateRun_sound` to packed certificates.

Packing convention (must match `impl/structured.py` row-major flattening):
  bit index of (i, j) ∈ Fin ℓ × Fin m  is  i*m + j.

Zero sorries, zero axioms, no native_decide — same contract as the rest of the
proof layer.
-/

import Mathlib
import proofs.DecoderCert

open QCCirculant QLDPC

namespace QLDPC.Packed

/-! ## Section 1: Unpacking Nat bitmasks to torus F₂ vectors -/

variable {ℓ m : ℕ}

/-- Bit index of a torus point (row-major, matching the Python pipeline). -/
def idx (g : Fin ℓ × Fin m) : ℕ := g.1.val * m + g.2.val

theorem idx_lt (g : Fin ℓ × Fin m) : idx g < ℓ * m := by
  have h1 := g.1.isLt
  have h2 := g.2.isLt
  calc g.1.val * m + g.2.val < g.1.val * m + m := by omega
    _ = (g.1.val + 1) * m := by ring
    _ ≤ ℓ * m := Nat.mul_le_mul_right m (by omega)

theorem idx_inj {g h : Fin ℓ × Fin m} (he : idx g = idx h) : g = h := by
  unfold idx at he
  have hg2 := g.2.isLt
  have hh2 := h.2.isLt
  have h1 : g.1.val = h.1.val := by
    rcases Nat.lt_trichotomy g.1.val h.1.val with hlt | heq | hgt
    · exfalso
      have hstep : (g.1.val + 1) * m ≤ h.1.val * m := Nat.mul_le_mul_right m hlt
      have : g.1.val * m + m ≤ h.1.val * m := by
        calc g.1.val * m + m = (g.1.val + 1) * m := by ring
          _ ≤ h.1.val * m := hstep
      omega
    · exact heq
    · exfalso
      have hstep : (h.1.val + 1) * m ≤ g.1.val * m := Nat.mul_le_mul_right m hgt
      have : h.1.val * m + m ≤ g.1.val * m := by
        calc h.1.val * m + m = (h.1.val + 1) * m := by ring
          _ ≤ g.1.val * m := hstep
      omega
  have h2 : g.2.val = h.2.val := by
    rw [h1] at he
    omega
  exact Prod.ext (Fin.ext h1) (Fin.ext h2)

/-- Unpack a Nat bitmask into a torus F₂ vector. This is the ONLY bridge between
    packed and semantic worlds; certificates define their run data through it. -/
def unpack (x : ℕ) : Fin ℓ × Fin m → ZMod 2 :=
  fun g => if x.testBit (idx g) then 1 else 0

@[simp] theorem unpack_zero : (unpack 0 : Fin ℓ × Fin m → ZMod 2) = 0 := by
  funext g
  simp [unpack]

/-- Unpacking commutes with XOR: bitwise xor is pointwise F₂ addition. -/
theorem unpack_xor (x y : ℕ) :
    (unpack (x ^^^ y) : Fin ℓ × Fin m → ZMod 2) = unpack x + unpack y := by
  funext g
  simp only [unpack, Pi.add_apply, Nat.testBit_xor]
  rcases hx : x.testBit (idx g) <;> rcases hy : y.testBit (idx g)
  all_goals simp
  all_goals decide

/-! ## Section 2: Parity of a Nat (provably = F₂ sum of its bits)

Used for the anticommutation pairing ⟨z, r⟩ = parity (z &&& r). Defined by
halving recursion so the kernel evaluates it with GMP div/mod in O(bits) steps,
and the correctness proof is a clean strong induction. -/

/-- Bits above the width bound of a bounded number are false. -/
theorem testBit_ge_bound {x w p : ℕ} (hx : x < 2 ^ w) (hp : w ≤ p) :
    x.testBit p = false :=
  Nat.testBit_eq_false_of_lt
    (lt_of_lt_of_le hx (Nat.pow_le_pow_right (by omega) hp))

/-- Fuel-driven bit-parity: STRUCTURAL recursion, so the kernel iota-reduces it
    (a well-founded definition would not kernel-evaluate). Fuel `log2 n + 1`
    bounds the recursion depth by the bit length. -/
def parityAux : ℕ → ℕ → Bool
  | 0, _ => false
  | fuel + 1, n =>
    if n = 0 then false
    else Bool.xor (decide (n % 2 = 1)) (parityAux fuel (n / 2))

/-- The F₂ sum of all bits of `n` below `w` (a semantic reference object). -/
def bitSum (n w : ℕ) : ZMod 2 :=
  ∑ i ∈ Finset.range w, if n.testBit i then 1 else 0

/-- `parityAux` with sufficient fuel computes the F₂ sum of the bits. -/
theorem parityAux_eq_bitSum (fuel : ℕ) : ∀ n, n < 2 ^ fuel →
    (if parityAux fuel n then (1 : ZMod 2) else 0) = bitSum n fuel := by
  induction fuel with
  | zero =>
    intro n h
    have hn : n = 0 := by simpa using h
    subst hn
    simp [parityAux, bitSum]
  | succ fuel ih =>
    intro n h
    rcases Nat.eq_zero_or_pos n with hn | hn
    · subst hn
      have hfalse : parityAux (fuel + 1) 0 = false := by simp [parityAux]
      rw [hfalse]
      unfold bitSum
      simp
    · have hne : n ≠ 0 := by omega
      have hstep : parityAux (fuel + 1) n
          = Bool.xor (decide (n % 2 = 1)) (parityAux fuel (n / 2)) := by
        simp [parityAux, hne]
      have hhalf : n / 2 < 2 ^ fuel := by
        have h2 : n < 2 * 2 ^ fuel := by
          have hpow : (2 : ℕ) ^ (fuel + 1) = 2 * 2 ^ fuel := by ring
          omega
        omega
      have hrec := ih (n / 2) hhalf
      have hsplit : bitSum n (fuel + 1) =
          bitSum (n / 2) fuel + (if n.testBit 0 then (1 : ZMod 2) else 0) := by
        unfold bitSum
        rw [Finset.sum_range_succ']
        congr 1
        refine Finset.sum_congr rfl fun i _ => ?_
        rw [Nat.testBit_add_one]
      rw [hsplit, ← hrec, hstep]
      have hb0 : n.testBit 0 = decide (n % 2 = 1) := Nat.testBit_zero n
      rcases hp : parityAux fuel (n / 2) <;> rcases hm : decide (n % 2 = 1)
      all_goals simp [hb0, hm]
      all_goals decide

/-! ## Section 3: Packed torus shifts via shifts and masks

`pshift x k` implements the reader `g ↦ x(g + k)` on packed bitmasks — the
primitive both `mulVecT` (transpose evaluation) and, with `-k`, `mulVecS`
(forward evaluation) need. Decomposition: a 2D torus shift is a column rotation
within each row (masked shifts with a per-row repeated mask) followed by a row
rotation (whole-block shifts). Every operation is kernel-accelerated Nat
arithmetic; every operation carries a proven `testBit` specification. -/

/-- The mask `pat` repeated in every one of `R` rows of width `m`. -/
def repMask (m pat : ℕ) : ℕ → ℕ
  | 0 => 0
  | R + 1 => (repMask m pat R <<< m) ||| pat

theorem repMask_lt {m pat : ℕ} (hpat : pat < 2 ^ m) :
    ∀ R, repMask m pat R < 2 ^ (R * m)
  | 0 => by simp [repMask]
  | R + 1 => by
    have ih := repMask_lt hpat R
    have h1 : repMask m pat R <<< m < 2 ^ ((R + 1) * m) := by
      rw [Nat.shiftLeft_eq]
      have h2m : 0 < (2 : ℕ) ^ m := Nat.two_pow_pos m
      calc repMask m pat R * 2 ^ m < 2 ^ (R * m) * 2 ^ m := by nlinarith
        _ = 2 ^ ((R + 1) * m) := by rw [← pow_add]; congr 1; ring
    have h2 : pat < 2 ^ ((R + 1) * m) := by
      calc pat < 2 ^ m := hpat
        _ ≤ 2 ^ ((R + 1) * m) := Nat.pow_le_pow_right (by omega) (by nlinarith)
    exact Nat.or_lt_two_pow h1 h2

theorem repMask_testBit {m pat : ℕ} (hpat : pat < 2 ^ m)
    {R r c : ℕ} (hr : r < R) (hc : c < m) :
    (repMask m pat R).testBit (r * m + c) = pat.testBit c := by
  induction R generalizing r with
  | zero => omega
  | succ R ih =>
    show ((repMask m pat R <<< m) ||| pat).testBit (r * m + c) = pat.testBit c
    rw [Nat.testBit_lor, Nat.testBit_shiftLeft]
    rcases Nat.eq_zero_or_pos r with hr0 | hrpos
    · -- row 0: position c < m, the shifted part contributes nothing
      subst hr0
      have hlt : ¬ (c ≥ m) := by omega
      simp only [Nat.zero_mul, Nat.zero_add, decide_eq_false hlt,
                 Bool.false_and, Bool.false_or]
    · -- row r ≥ 1: the low pattern contributes nothing, recurse into rows above
      obtain ⟨r', rfl⟩ : ∃ r', r = r' + 1 := ⟨r - 1, by omega⟩
      have hge : (r' + 1) * m + c ≥ m := by nlinarith
      have hpos : (r' + 1) * m + c - m = r' * m + c := by
        have : (r' + 1) * m = r' * m + m := by ring
        omega
      have hpatbit : pat.testBit ((r' + 1) * m + c) = false :=
        testBit_ge_bound hpat hge
      rw [decide_eq_true hge, hpatbit, Bool.true_and, Bool.or_false, hpos]
      exact ih (by omega)

/-- Rotate rows: output bit (r, c) reads input bit ((r + ki) mod ℓ, c). -/
def rowShift (ℓ m x ki : ℕ) : ℕ :=
  ((x >>> (ki * m)) ||| (x <<< ((ℓ - ki) * m))) % 2 ^ (ℓ * m)

theorem rowShift_lt (ℓ m x ki : ℕ) : rowShift ℓ m x ki < 2 ^ (ℓ * m) :=
  Nat.mod_lt _ (Nat.two_pow_pos _)

theorem rowShift_testBit {ℓ m x ki r c : ℕ}
    (hki : ki < ℓ) (hx : x < 2 ^ (ℓ * m)) (hr : r < ℓ) (hc : c < m) :
    (rowShift ℓ m x ki).testBit (r * m + c) =
      x.testBit (((r + ki) % ℓ) * m + c) := by
  have hp : r * m + c < ℓ * m := by nlinarith
  unfold rowShift
  rw [Nat.testBit_mod_two_pow, decide_eq_true hp, Bool.true_and,
      Nat.testBit_lor, Nat.testBit_shiftRight, Nat.testBit_shiftLeft]
  have hshift1 : ki * m + (r * m + c) = (r + ki) * m + c := by ring
  rcases Nat.lt_or_ge (r + ki) ℓ with hcase | hcase
  · -- no wraparound: (r+ki) % ℓ = r+ki; shifted-left branch is dead
    rw [Nat.mod_eq_of_lt hcase, hshift1]
    have hdead : ¬ (r * m + c ≥ (ℓ - ki) * m) := by
      have h1 : (r + 1) * m ≤ (ℓ - ki) * m :=
        Nat.mul_le_mul_right m (by omega)
      have h2 : (r + 1) * m = r * m + m := by ring
      omega
    simp [decide_eq_false hdead]
  · -- wraparound: (r+ki) % ℓ = r+ki-ℓ; shifted-right branch is dead
    have hmod : (r + ki) % ℓ = r + ki - ℓ := by
      rw [Nat.mod_eq_sub_mod hcase]
      exact Nat.mod_eq_of_lt (by omega)
    rw [hmod, hshift1]
    have hdead : x.testBit ((r + ki) * m + c) = false := by
      refine testBit_ge_bound hx ?_
      have : ℓ * m ≤ (r + ki) * m := Nat.mul_le_mul_right m hcase
      omega
    have hlive : r * m + c ≥ (ℓ - ki) * m := by
      have h1 : (ℓ - ki) * m ≤ r * m := Nat.mul_le_mul_right m (by omega)
      omega
    have hpos : r * m + c - (ℓ - ki) * m = (r + ki - ℓ) * m + c := by
      have h1 : (ℓ - ki) * m ≤ r * m := Nat.mul_le_mul_right m (by omega)
      have h2 : (r + ki - ℓ) * m + (ℓ - ki) * m = r * m := by
        rw [← Nat.add_mul]
        congr 1
        omega
      omega
    rw [hdead, decide_eq_true hlive, hpos]
    simp

/-- Rotate columns within each row: output bit (r, c) reads input bit
    (r, (c + kj) mod m). -/
def colShift (ℓ m x kj : ℕ) : ℕ :=
  ((x >>> kj) &&& repMask m (2 ^ (m - kj) - 1) ℓ) |||
  ((x <<< (m - kj)) &&& repMask m ((2 ^ kj - 1) <<< (m - kj)) ℓ)

private theorem pat_lo_lt {m kj : ℕ} : 2 ^ (m - kj) - 1 < 2 ^ m := by
  have h1 : (2 : ℕ) ^ (m - kj) ≤ 2 ^ m := Nat.pow_le_pow_right (by omega) (by omega)
  have h2 : 0 < (2 : ℕ) ^ (m - kj) := Nat.two_pow_pos _
  omega

private theorem pat_hi_lt {m kj : ℕ} (hkj : kj < m) :
    (2 ^ kj - 1) <<< (m - kj) < 2 ^ m := by
  rw [Nat.shiftLeft_eq]
  have h2 : 0 < (2 : ℕ) ^ kj := Nat.two_pow_pos _
  have h3 : 0 < (2 : ℕ) ^ (m - kj) := Nat.two_pow_pos _
  have h4 : (2 : ℕ) ^ kj - 1 < 2 ^ kj := by omega
  calc (2 ^ kj - 1) * 2 ^ (m - kj) < 2 ^ kj * 2 ^ (m - kj) :=
        (Nat.mul_lt_mul_right h3).mpr h4
    _ = 2 ^ m := by rw [← pow_add]; congr 1; omega

theorem colShift_lt {ℓ m x kj : ℕ} (hkj : kj < m) :
    colShift ℓ m x kj < 2 ^ (ℓ * m) := by
  unfold colShift
  refine Nat.or_lt_two_pow ?_ ?_
  · exact lt_of_le_of_lt Nat.and_le_right (repMask_lt pat_lo_lt ℓ)
  · exact lt_of_le_of_lt Nat.and_le_right (repMask_lt (pat_hi_lt hkj) ℓ)

theorem colShift_testBit {ℓ m x kj r c : ℕ}
    (hkj : kj < m) (hr : r < ℓ) (hc : c < m) :
    (colShift ℓ m x kj).testBit (r * m + c) =
      x.testBit (r * m + (c + kj) % m) := by
  unfold colShift
  rw [Nat.testBit_lor, Nat.testBit_land, Nat.testBit_land,
      Nat.testBit_shiftRight, Nat.testBit_shiftLeft,
      repMask_testBit pat_lo_lt hr hc, repMask_testBit (pat_hi_lt hkj) hr hc,
      Nat.testBit_two_pow_sub_one, Nat.testBit_shiftLeft,
      Nat.testBit_two_pow_sub_one]
  rcases Nat.lt_or_ge (c + kj) m with hcase | hcase
  · -- no wraparound: (c+kj) % m = c+kj; hi branch dead via its mask
    rw [Nat.mod_eq_of_lt hcase]
    have hlo : c < m - kj := by omega
    have hhi : ¬ (c ≥ m - kj) := by omega
    have hpos : kj + (r * m + c) = r * m + (c + kj) := by ring
    rw [hpos]
    simp only [decide_eq_true hlo, decide_eq_false hhi, Bool.and_true,
               Bool.false_and, Bool.and_false, Bool.or_false]
  · -- wraparound: (c+kj) % m = c+kj-m; lo branch dead via its mask
    have hmod : (c + kj) % m = c + kj - m := by
      rw [Nat.mod_eq_sub_mod hcase]
      exact Nat.mod_eq_of_lt (by omega)
    rw [hmod]
    have hlo : ¬ (c < m - kj) := by omega
    have hhi : c ≥ m - kj := by omega
    have hhi2 : c - (m - kj) < kj := by omega
    have hlive : r * m + c ≥ m - kj := by omega
    have hpos : r * m + c - (m - kj) = r * m + (c + kj - m) := by omega
    rw [hpos]
    simp only [decide_eq_false hlo, decide_eq_true hhi, decide_eq_true hhi2,
               decide_eq_true hlive, Bool.and_false, Bool.false_or,
               Bool.true_and, Bool.and_true]

/-- The packed torus shift: `unpack (pshift x k) = fun g => unpack x (g + k)`. -/
def pshift {ℓ m : ℕ} (x : ℕ) (k : Fin ℓ × Fin m) : ℕ :=
  rowShift ℓ m (colShift ℓ m x k.2.val) k.1.val

theorem pshift_lt {ℓ m : ℕ} (x : ℕ) (k : Fin ℓ × Fin m) :
    pshift x k < 2 ^ (ℓ * m) :=
  rowShift_lt ℓ m _ _

theorem pshift_testBit {ℓ m : ℕ} (x : ℕ) (k g : Fin ℓ × Fin m) :
    (pshift x k).testBit (idx g) = x.testBit (idx (g + k)) := by
  have hcol : colShift ℓ m x k.2.val < 2 ^ (ℓ * m) := colShift_lt k.2.isLt
  show (rowShift ℓ m (colShift ℓ m x k.2.val) k.1.val).testBit
        (g.1.val * m + g.2.val) = _
  rw [rowShift_testBit k.1.isLt hcol g.1.isLt g.2.isLt,
      colShift_testBit k.2.isLt (Nat.mod_lt _ k.1.pos) g.2.isLt]
  have hidx : idx (g + k) = ((g.1.val + k.1.val) % ℓ) * m + (g.2.val + k.2.val) % m := by
    show (g + k).1.val * m + (g + k).2.val = _
    rw [Prod.fst_add, Prod.snd_add, Fin.val_add, Fin.val_add]
  rw [hidx]

/-- Unpacking a shift is reading at a shifted point. -/
theorem unpack_pshift {ℓ m : ℕ} (x : ℕ) (k : Fin ℓ × Fin m) :
    (unpack (pshift x k) : Fin ℓ × Fin m → ZMod 2) =
      fun g => unpack x (g + k) := by
  funext g
  simp only [unpack, pshift_testBit x k g]

/-! ## Section 4: Packed sparse evaluation and the F₂ pairing -/

instance : Std.Commutative (α := ℕ) (· ^^^ ·) := ⟨Nat.xor_comm⟩
instance : Std.Associative (α := ℕ) (· ^^^ ·) := ⟨Nat.xor_assoc⟩

/-- XOR-accumulate `f` over a finite set (order-independent by commutativity). -/
def pXor {α : Type*} [DecidableEq α] (s : Finset α) (f : α → ℕ) : ℕ :=
  s.fold (· ^^^ ·) 0 f

theorem unpack_pXor {ℓ m : ℕ} {α : Type*} [DecidableEq α]
    (s : Finset α) (f : α → ℕ) :
    (unpack (pXor s f) : Fin ℓ × Fin m → ZMod 2) = ∑ k ∈ s, unpack (f k) := by
  induction s using Finset.cons_induction with
  | empty => simp [pXor]
  | cons a s ha ih =>
    rw [Finset.sum_cons, ← ih]
    show unpack (Finset.fold (· ^^^ ·) 0 f (Finset.cons a s ha)) = _
    rw [Finset.fold_cons, unpack_xor]
    rfl

/-- Packed transpose evaluation. -/
def pMulVecT {ℓ m : ℕ} (s : Finset (Fin ℓ × Fin m)) (x : ℕ) : ℕ :=
  pXor s (fun k => pshift x k)

theorem unpack_pMulVecT {ℓ m : ℕ} [NeZero ℓ] [NeZero m]
    (s : Finset (Fin ℓ × Fin m)) (x : ℕ) :
    (unpack (pMulVecT s x) : Fin ℓ × Fin m → ZMod 2) =
      SparsePoly.mulVecT ⟨s⟩ (unpack x) := by
  unfold pMulVecT
  rw [unpack_pXor]
  funext g
  rw [Finset.sum_apply]
  show _ = ∑ k ∈ s, unpack x (k + g)
  refine Finset.sum_congr rfl fun k _ => ?_
  rw [unpack_pshift]
  simp [add_comm]

/-- Packed forward evaluation (reads at `g - k`, i.e. shift by `-k`). -/
def pMulVecS {ℓ m : ℕ} [NeZero ℓ] [NeZero m]
    (s : Finset (Fin ℓ × Fin m)) (x : ℕ) : ℕ :=
  pXor s (fun k => pshift x (-k))

theorem unpack_pMulVecS {ℓ m : ℕ} [NeZero ℓ] [NeZero m]
    (s : Finset (Fin ℓ × Fin m)) (x : ℕ) :
    (unpack (pMulVecS s x) : Fin ℓ × Fin m → ZMod 2) =
      SparsePoly.mulVecS ⟨s⟩ (unpack x) := by
  unfold pMulVecS
  rw [unpack_pXor]
  funext g
  rw [Finset.sum_apply]
  show _ = ∑ k ∈ s, unpack x (g - k)
  refine Finset.sum_congr rfl fun k _ => ?_
  rw [unpack_pshift]
  simp [sub_eq_add_neg]

/-- Packed F₂ pairing: parity of the AND, with an explicit bit-width fuel
    (a literal like `ℓ*m` at every call site, so the kernel iota-reduces it —
    a `log2`-derived fuel would be well-founded recursion and would NOT reduce). -/
def pDot (w a b : ℕ) : Bool := parityAux w (a &&& b)

/-- The packed pairing agrees with `dotF2` on unpacked vectors (given a bound on
    one side, so no garbage bits beyond the torus contribute). -/
theorem pDot_eq_dotF2 {ℓ m : ℕ} {a : ℕ} (b : ℕ) (ha : a < 2 ^ (ℓ * m)) :
    (if pDot (ℓ * m) a b then (1 : ZMod 2) else 0) =
      dotF2 (unpack a : Fin ℓ × Fin m → ZMod 2) (unpack b) := by
  have hab : a &&& b < 2 ^ (ℓ * m) := lt_of_le_of_lt Nat.and_le_left ha
  unfold pDot
  rw [parityAux_eq_bitSum (ℓ * m) _ hab]
  unfold bitSum dotF2
  rw [← Fin.sum_univ_eq_sum_range
        (fun i => if (a &&& b).testBit i then (1 : ZMod 2) else 0)]
  have hbij : Function.Bijective
      (fun g : Fin ℓ × Fin m => (⟨idx g, idx_lt g⟩ : Fin (ℓ * m))) := by
    rw [Fintype.bijective_iff_injective_and_card]
    refine ⟨fun g h hgh => idx_inj ?_, by simp⟩
    simpa using congrArg Fin.val hgh
  rw [← Function.Bijective.sum_comp hbij
        (fun i : Fin (ℓ * m) => if (a &&& b).testBit i.val then (1 : ZMod 2) else 0)]
  refine Finset.sum_congr rfl fun g _ => ?_
  simp only [unpack, Nat.testBit_land]
  rcases hA : a.testBit (idx g) <;> rcases hB : b.testBit (idx g)
  all_goals simp

/-! ## Section 5: Packed run certificates and the master soundness transfer -/

/-- A decode-run certificate in packed form: five bitmasks plus a packed
    outcome witness. This is what `certgen.py` emits and the kernel evaluates. -/
structure PackedRun where
  observed : ℕ
  corr1 : ℕ
  corr2 : ℕ
  inj1 : ℕ
  inj2 : ℕ
  witness : ℕ ⊕ (ℕ × ℕ)

/-- Unpack a packed run into the semantic `DecodeRunCert`. -/
def toRun {ℓ m : ℕ} (pr : PackedRun) : DecoderCert.DecodeRunCert (Fin ℓ × Fin m) :=
  { observed := unpack pr.observed
    correction := (unpack pr.corr1, unpack pr.corr2)
    injected := (unpack pr.inj1, unpack pr.inj2)
    residualWitness :=
      match pr.witness with
      | .inl w => .inl (unpack w)
      | .inr (z1, z2) => .inr (unpack z1, unpack z2) }

/-- The packed validator: pure kernel-accelerated Nat arithmetic. -/
def pValidateRun {ℓ m : ℕ} [NeZero ℓ] [NeZero m]
    (c : GBCode (Fin ℓ × Fin m)) (pr : PackedRun) : Bool :=
  let M := 2 ^ (ℓ * m)
  let r1 := pr.corr1 ^^^ pr.inj1
  let r2 := pr.corr2 ^^^ pr.inj2
  decide (pr.corr1 < M) && decide (pr.corr2 < M) &&
  decide (pr.inj1 < M) && decide (pr.inj2 < M) &&
  decide (pMulVecT c.b.support pr.corr1 ^^^ pMulVecT c.a.support pr.corr2
            = pr.observed) &&
  decide (pMulVecT c.b.support pr.inj1 ^^^ pMulVecT c.a.support pr.inj2
            = pr.observed) &&
  match pr.witness with
  | .inl w =>
      decide (pMulVecT c.a.support w = r1) && decide (pMulVecT c.b.support w = r2)
  | .inr (z1, z2) =>
      decide (z1 < M) && decide (z2 < M) &&
      decide (pMulVecS c.a.support z1 ^^^ pMulVecS c.b.support z2 = 0) &&
      (Bool.xor (pDot (ℓ * m) z1 r1) (pDot (ℓ * m) z2 r2))

/-- **Master transfer theorem (Stage A)**: if the packed validator accepts, the
    semantic validator of `DecoderCert.lean` accepts the unpacked run. Composing
    with `DecoderCert.validateRun_sound` yields all semantic conclusions (dense
    syndrome consistency of both vectors, residual ∈ ker H_Z, certified logical
    outcome) for kernel-checked packed certificates:

    `DecoderCert.validateRun_sound c (toRun pr) (pValidateRun_sound_transfer c pr h)`. -/
theorem pValidateRun_sound_transfer {ℓ m : ℕ} [NeZero ℓ] [NeZero m]
    (c : GBCode (Fin ℓ × Fin m))
    (pr : PackedRun) (h : pValidateRun c pr = true) :
    DecoderCert.validateRun c (toRun pr) = true := by
  obtain ⟨obs, c1, c2, i1, i2, wit⟩ := pr
  cases wit with
  | inl w =>
    unfold pValidateRun at h
    simp only [Bool.and_eq_true, decide_eq_true_eq] at h
    obtain ⟨⟨⟨⟨⟨⟨hc1, hc2⟩, hi1⟩, hi2⟩, hsynC⟩, hsynI⟩, hw1, hw2⟩ := h
    unfold DecoderCert.validateRun
    simp only [Bool.and_eq_true]
    refine ⟨⟨?_, ?_⟩, ?_⟩
    · rw [DecoderCert.checkSyndromeZ_iff_sparse]
      have hu := congrArg (unpack (ℓ := ℓ) (m := m)) hsynC
      rw [unpack_xor, unpack_pMulVecT, unpack_pMulVecT] at hu
      exact hu
    · rw [DecoderCert.checkSyndromeZ_iff_sparse]
      have hu := congrArg (unpack (ℓ := ℓ) (m := m)) hsynI
      rw [unpack_xor, unpack_pMulVecT, unpack_pMulVecT] at hu
      exact hu
    · show DecoderCert.checkSuccessWitness c _ _ = true
      unfold DecoderCert.checkSuccessWitness
      rw [decide_eq_true_eq]
      have h1 := congrArg (unpack (ℓ := ℓ) (m := m)) hw1
      have h2 := congrArg (unpack (ℓ := ℓ) (m := m)) hw2
      rw [unpack_pMulVecT, unpack_xor] at h1
      rw [unpack_pMulVecT, unpack_xor] at h2
      exact Prod.ext h1 h2
  | inr z =>
    obtain ⟨z1, z2⟩ := z
    unfold pValidateRun at h
    simp only [Bool.and_eq_true, decide_eq_true_eq] at h
    obtain ⟨⟨⟨⟨⟨⟨hc1, hc2⟩, hi1⟩, hi2⟩, hsynC⟩, hsynI⟩, ⟨⟨hz1, hz2⟩, hker⟩, hdot⟩ := h
    unfold DecoderCert.validateRun
    simp only [Bool.and_eq_true]
    refine ⟨⟨?_, ?_⟩, ?_⟩
    · rw [DecoderCert.checkSyndromeZ_iff_sparse]
      have hu := congrArg (unpack (ℓ := ℓ) (m := m)) hsynC
      rw [unpack_xor, unpack_pMulVecT, unpack_pMulVecT] at hu
      exact hu
    · rw [DecoderCert.checkSyndromeZ_iff_sparse]
      have hu := congrArg (unpack (ℓ := ℓ) (m := m)) hsynI
      rw [unpack_xor, unpack_pMulVecT, unpack_pMulVecT] at hu
      exact hu
    · show DecoderCert.checkFailureWitness c _ _ = true
      unfold DecoderCert.checkFailureWitness
      rw [Bool.and_eq_true, decide_eq_true_eq, decide_eq_true_eq]
      constructor
      · have hu := congrArg (unpack (ℓ := ℓ) (m := m)) hker
        rw [unpack_xor, unpack_pMulVecS, unpack_pMulVecS, unpack_zero] at hu
        exact hu
      · have hd1 := pDot_eq_dotF2 (ℓ := ℓ) (m := m) (c1 ^^^ i1) hz1
        have hd2 := pDot_eq_dotF2 (ℓ := ℓ) (m := m) (c2 ^^^ i2) hz2
        show DecoderCert.dot2 (unpack z1, unpack z2)
            ((unpack c1, unpack c2) + (unpack i1, unpack i2)) = 1
        show dotF2 (unpack z1) (unpack c1 + unpack i1)
            + dotF2 (unpack z2) (unpack c2 + unpack i2) = 1
        rw [← unpack_xor, ← unpack_xor, ← hd1, ← hd2]
        rcases hp1 : pDot (ℓ * m) z1 (c1 ^^^ i1) <;>
          rcases hp2 : pDot (ℓ * m) z2 (c2 ^^^ i2)
        all_goals rw [hp1, hp2] at hdot
        all_goals simp_all

end QLDPC.Packed