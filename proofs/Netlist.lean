-- Copyright (c) 2026 Justin Arndt. All rights reserved.
-- Licensed under the GNU GPLv3. For commercial licensing and proprietary
-- hardware mapping, see the LICENSE file (dual-licensing notice at top).
/-
# Netlist — Stage B: Verified Word-Level RTL for the Packed Checker

IRONCLAD-QLDPC Stage B (see ROADMAP.md). 2026-07-05.

## Design

A word-level RTL expression language over (ℓ·m)-bit words whose primitive
semantics ARE the proven packed operations of `PackedCert.lean` (`pMulVecT`,
`pMulVecS`, `pDot`, xor). Circuit correctness therefore reduces to Stage A's
theorems instead of re-proving bit arithmetic; the theorems below are
definitional-to-short.

Three checker circuits are built per code:
  - `synCheckC`  : syndrome consistency (production mode, per shot),
  - `successC`   : success witness `H_Xᵀw = r` (audit shots),
  - `failC`      : failure witness `H_X z = 0 ∧ ⟨z,r⟩ = 1` (audit shots).

`circuits_eq_pValidateRun_*` prove that the circuit conjunction IS the packed
validator, so every conclusion of `pValidateRun_sound_transfer` +
`validateRun_sound` applies to circuit-accepted runs.

## Trusted-printer boundary (stated precisely)

`emitVerilog`/`emitJSON` pretty-print the SAME expression trees to bit-blasted
synthesizable Verilog / a JSON netlist. The printers are trusted (≈100 lines of
string assembly; index arithmetic is computed in Lean from the same `Fin`
operations the semantics use). The printed netlist is then INDEPENDENTLY
checked against the Python pipeline by `impl/rtl_equiv.py` with basis-complete
equivalence tests on every linear layer (a linear map is determined by its
action on a basis, so those tests are complete, not sampled).

Zero sorries, zero project axioms, no native_decide.
-/

import Mathlib
import proofs.PackedCert

open QLDPC QLDPC.Packed

namespace QLDPC.RTL

/-! ## Section 1: Word-level expressions and their (proven) semantics -/

/-- Word-level RTL expressions over (ℓ·m)-bit words. `mulT`/`mulS` are the
    sparse circulant evaluations (Verilog: xor of torus-rotated copies —
    bit-blasted by the printer); `xorW` is vector xor. -/
inductive WExpr (ℓ m : ℕ) where
  | inp  (i : ℕ)
  | xorW (a b : WExpr ℓ m)
  | mulT (s : Finset (Fin ℓ × Fin m)) (e : WExpr ℓ m)
  | mulS (s : Finset (Fin ℓ × Fin m)) (e : WExpr ℓ m)

/-- Boolean-output layer: equality comparator (Verilog `~|(a^b)`), zero test
    (`~|e`), and the pairing `parity(a&b)` (Verilog reduction-xor `^(a&b)`). -/
inductive BExpr (ℓ m : ℕ) where
  | eqW  (a b : WExpr ℓ m)
  | isZ  (e : WExpr ℓ m)
  | parA (a b : WExpr ℓ m)
  | xorB (a b : BExpr ℓ m)
  | andB (a b : BExpr ℓ m)

variable {ℓ m : ℕ} [NeZero ℓ] [NeZero m]

/-- Word semantics: the proven packed operations. -/
def weval (env : List ℕ) : WExpr ℓ m → ℕ
  | .inp i => env.getD i 0
  | .xorW a b => weval env a ^^^ weval env b
  | .mulT s e => pMulVecT s (weval env e)
  | .mulS s e => pMulVecS s (weval env e)

/-- Boolean semantics. -/
def beval (env : List ℕ) : BExpr ℓ m → Bool
  | .eqW a b => decide (weval env a = weval env b)
  | .isZ e => decide (weval env e = 0)
  | .parA a b => pDot (ℓ * m) (weval env a) (weval env b)
  | .xorB a b => Bool.xor (beval env a) (beval env b)
  | .andB a b => beval env a && beval env b

/-! ## Section 2: The three checker circuits

Input word conventions: `synCheckC` reads `[s, e1, e2]`; `successC` reads
`[c1, c2, i1, i2, w]`; `failC` reads `[c1, c2, i1, i2, z1, z2]`. -/

/-- Syndrome-consistency circuit: `H_Z · e = s` via sparse evaluation. -/
def synCheckC (c : GBCode (Fin ℓ × Fin m)) : BExpr ℓ m :=
  .eqW (.xorW (.mulT c.b.support (.inp 1)) (.mulT c.a.support (.inp 2))) (.inp 0)

/-- Success-witness circuit: `H_Xᵀ w = r` on both blocks (r = corr ⊕ inj). -/
def successC (c : GBCode (Fin ℓ × Fin m)) : BExpr ℓ m :=
  .andB (.eqW (.mulT c.a.support (.inp 4)) (.xorW (.inp 0) (.inp 2)))
        (.eqW (.mulT c.b.support (.inp 4)) (.xorW (.inp 1) (.inp 3)))

/-- Failure-witness circuit: `H_X z = 0` and `⟨z, r⟩ = 1`. -/
def failC (c : GBCode (Fin ℓ × Fin m)) : BExpr ℓ m :=
  .andB (.isZ (.xorW (.mulS c.a.support (.inp 4)) (.mulS c.b.support (.inp 5))))
        (.xorB (.parA (.inp 4) (.xorW (.inp 0) (.inp 2)))
               (.parA (.inp 5) (.xorW (.inp 1) (.inp 3))))

/-! ## Section 3: Circuit correctness = the packed validator

Because the primitives share semantics with `pValidateRun`'s operations, the
circuit conjunction equals the validator definitionally (up to `Bool.and`
re-association, handled by `ac_rfl`-free explicit restatement). -/

/-- Bounds guard shared by both validator branches. -/
def boundsOK (ℓ m c1 c2 i1 i2 : ℕ) : Bool :=
  decide (c1 < 2 ^ (ℓ * m)) && decide (c2 < 2 ^ (ℓ * m)) &&
  decide (i1 < 2 ^ (ℓ * m)) && decide (i2 < 2 ^ (ℓ * m))

/-- **Stage B master (success branch)**: the packed validator IS the circuit
    conjunction — bounds, syndrome circuit on the correction, syndrome circuit
    on the injected error, success circuit. -/
theorem circuits_eq_pValidateRun_inl (c : GBCode (Fin ℓ × Fin m))
    (o c1 c2 i1 i2 w : ℕ) :
    pValidateRun c ⟨o, c1, c2, i1, i2, .inl w⟩ =
      (boundsOK ℓ m c1 c2 i1 i2 &&
       beval [o, c1, c2] (synCheckC c) &&
       beval [o, i1, i2] (synCheckC c) &&
       beval [c1, c2, i1, i2, w] (successC c)) := by
  simp only [pValidateRun, boundsOK, beval, weval, synCheckC, successC,
             List.getD, Bool.and_assoc]
  rfl

/-- **Stage B master (failure branch)**. -/
theorem circuits_eq_pValidateRun_inr (c : GBCode (Fin ℓ × Fin m))
    (o c1 c2 i1 i2 z1 z2 : ℕ) :
    pValidateRun c ⟨o, c1, c2, i1, i2, .inr (z1, z2)⟩ =
      (boundsOK ℓ m c1 c2 i1 i2 &&
       beval [o, c1, c2] (synCheckC c) &&
       beval [o, i1, i2] (synCheckC c) &&
       (decide (z1 < 2 ^ (ℓ * m)) && decide (z2 < 2 ^ (ℓ * m)) &&
        beval [c1, c2, i1, i2, z1, z2] (failC c))) := by
  simp only [pValidateRun, boundsOK, beval, weval, synCheckC, failC,
             List.getD, Bool.and_assoc]
  rfl

/-! ## Section 4: Bit-blasted emission (trusted printer)

Everything below is STRING ASSEMBLY — no theorems depend on it. Index
arithmetic reuses the same `Fin` addition/negation the semantics use, computed
at emission time on the concrete code. -/

/-- All torus points in bit order (`#eval`-computable). -/
def allPoints (ℓ m : ℕ) [NeZero ℓ] [NeZero m] : List (Fin ℓ × Fin m) :=
  (List.range (ℓ * m)).map (fun p =>
    (⟨p / m % ℓ, Nat.mod_lt _ (NeZero.pos ℓ)⟩, ⟨p % m, Nat.mod_lt _ (NeZero.pos m)⟩))

/-- Computable, deterministic support enumeration (`Finset.toList` is
    noncomputable; filtering the ordered point list is not). -/
def suppList (s : Finset (Fin ℓ × Fin m)) : List (Fin ℓ × Fin m) :=
  (allPoints ℓ m).filter (· ∈ s)

/-- Bit index list read by output bit `g` of a `mulT`: positions `idx (g + k)`. -/
def tapsT (s : Finset (Fin ℓ × Fin m)) (g : Fin ℓ × Fin m) : List ℕ :=
  (suppList s).map (fun k => idx (g + k))

/-- Taps for `mulS`: positions `idx (g - k)`. -/
def tapsS (s : Finset (Fin ℓ × Fin m)) (g : Fin ℓ × Fin m) : List ℕ :=
  (suppList s).map (fun k => idx (g - k))

private def xorOf (name : String) (taps : List ℕ) : String :=
  match taps with
  | [] => "1'b0"
  | ts => " ^ ".intercalate (ts.map (fun t => name ++ "[" ++ toString t ++ "]"))

/-- Verilog for the three checker circuits of one code (one module). -/
def emitVerilog (c : GBCode (Fin ℓ × Fin m)) (modName : String) : String :=
  let n := ℓ * m
  let w := "[" ++ toString (n - 1) ++ ":0]"
  let pts := allPoints ℓ m
  let synBody := String.intercalate "\n" (pts.map (fun g =>
    "  assign syn[" ++ toString (idx g) ++ "] = " ++
      xorOf "e1" (tapsT c.b.support g) ++ " ^ " ++
      xorOf "e2" (tapsT c.a.support g) ++ ";"))
  let sucABody := String.intercalate "\n" (pts.map (fun g =>
    "  assign sw1[" ++ toString (idx g) ++ "] = " ++
      xorOf "wv" (tapsT c.a.support g) ++ ";"))
  let sucBBody := String.intercalate "\n" (pts.map (fun g =>
    "  assign sw2[" ++ toString (idx g) ++ "] = " ++
      xorOf "wv" (tapsT c.b.support g) ++ ";"))
  let failBody := String.intercalate "\n" (pts.map (fun g =>
    "  assign fx[" ++ toString (idx g) ++ "] = " ++
      xorOf "z1" (tapsS c.a.support g) ++ " ^ " ++
      xorOf "z2" (tapsS c.b.support g) ++ ";"))
  String.intercalate "\n"
    [ "// Copyright (c) 2026 Justin Arndt. All rights reserved."
    , "// Licensed under the GNU GPLv3. For commercial licensing and proprietary"
    , "// hardware mapping, see the LICENSE file (dual-licensing notice at top)."
    , "//"
    , "// Auto-generated by proofs/Netlist.lean (Stage B trusted printer)."
    , "// Semantics proven in Lean: circuits_eq_pValidateRun_{inl,inr} +"
    , "// pValidateRun_sound_transfer. Independently checked by impl/rtl_equiv.py."
    , "module " ++ modName ++ " ("
    , "  input  " ++ w ++ " obs, input " ++ w ++ " c1, input " ++ w ++ " c2,"
    , "  input  " ++ w ++ " i1,  input " ++ w ++ " i2,"
    , "  input  " ++ w ++ " wv,  input " ++ w ++ " z1, input " ++ w ++ " z2,"
    , "  output syn_ok_corr, output syn_ok_inj, output success_ok, output fail_ok);"
    , "  wire " ++ w ++ " e1 = c1;  wire " ++ w ++ " e2 = c2;"
    , "  wire " ++ w ++ " j1 = i1;  wire " ++ w ++ " j2 = i2;"
    , "  wire " ++ w ++ " r1 = c1 ^ i1;  wire " ++ w ++ " r2 = c2 ^ i2;"
    , "  wire " ++ w ++ " syn, syn_i, sw1, sw2, fx;"
    , synBody
    , "  // injected-error syndrome shares the same taps on (j1, j2):"
    , String.intercalate "\n" (pts.map (fun g =>
        "  assign syn_i[" ++ toString (idx g) ++ "] = " ++
          xorOf "j1" (tapsT c.b.support g) ++ " ^ " ++
          xorOf "j2" (tapsT c.a.support g) ++ ";"))
    , sucABody
    , sucBBody
    , failBody
    , "  assign syn_ok_corr = ~|(syn ^ obs);"
    , "  assign syn_ok_inj  = ~|(syn_i ^ obs);"
    , "  assign success_ok  = (~|(sw1 ^ r1)) & (~|(sw2 ^ r2));"
    , "  assign fail_ok     = (~|fx) & ((^(z1 & r1)) ^ (^(z2 & r2)));"
    , "endmodule"
    , "" ]

/-- JSON netlist (taps per output bit) for the Python equivalence harness. -/
def emitJSON (c : GBCode (Fin ℓ × Fin m)) (name : String) : String :=
  let pts := allPoints ℓ m
  let tapList := fun (f : Fin ℓ × Fin m → List ℕ) =>
    "[" ++ ", ".intercalate (pts.map (fun g =>
      "[" ++ ", ".intercalate ((f g).map toString) ++ "]")) ++ "]"
  String.intercalate "\n"
    [ "{"
    , "  \"name\": \"" ++ name ++ "\","
    , "  \"l\": " ++ toString ℓ ++ ", \"m\": " ++ toString m ++ ","
    , "  \"syn_taps_b_on_e1\": " ++ tapList (tapsT c.b.support) ++ ","
    , "  \"syn_taps_a_on_e2\": " ++ tapList (tapsT c.a.support) ++ ","
    , "  \"stab_taps_a_on_w\": " ++ tapList (tapsT c.a.support) ++ ","
    , "  \"stab_taps_b_on_w\": " ++ tapList (tapsT c.b.support) ++ ","
    , "  \"failx_taps_a_on_z1\": " ++ tapList (tapsS c.a.support) ++ ","
    , "  \"failx_taps_b_on_z2\": " ++ tapList (tapsS c.b.support)
    , "}" ]

end QLDPC.RTL
