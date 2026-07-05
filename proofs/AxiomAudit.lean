-- Copyright (c) 2026 Justin Arndt. All rights reserved.
-- Licensed under the GNU GPLv3. For commercial licensing and proprietary
-- hardware mapping, see the LICENSE file (dual-licensing notice at top).
/-
# AxiomAudit — Machine-Recorded Axiom Footprint of All Main Theorems

IRONCLAD-QLDPC extension, file F4. 2026-07-05.

Running `lake build proofs.AxiomAudit` prints the axiom dependencies of every
main theorem in the QLDPC extension into the build log. Expected footprint:
at most the three standard Lean/mathlib axioms

  `propext`, `Classical.choice`, `Quot.sound`

and NOTHING else. In particular, none of the theorems below may depend on any
project-introduced axiom (the base repo's `solver_achieves_bound` axiom pattern
is exactly what this extension replaces with kernel-checked `decide`
certificates).

The audit pipeline hashes this file and greps the build log to confirm the
footprint; a third party can re-run it with one command.
-/

import proofs.QCCirculant
import proofs.BBCode
import proofs.DecoderCert
import proofs.PackedCert
import proofs.Netlist

-- F1: circulant algebra bridge
#print axioms QCCirculant.circulant_mulVec
#print axioms QCCirculant.SparsePoly.mulVecS_eq_mulVec
#print axioms QCCirculant.SparsePoly.mulVecT_eq_mulVec
#print axioms QCCirculant.dotF2_mulVecT_left
#print axioms QCCirculant.SparsePoly.mulVecS_translate
#print axioms QCCirculant.SparsePoly.mulVecT_translate

-- F2: two-block group-algebra codes
#print axioms QLDPC.GBCode.syndromeX_eq_dense
#print axioms QLDPC.GBCode.syndromeZ_eq_dense
#print axioms QLDPC.GBCode.xStab_eq_dense
#print axioms QLDPC.GBCode.css_ZX
#print axioms QLDPC.GBCode.css_XZ
#print axioms QLDPC.GBCode.css_matrix
#print axioms QLDPC.GBCode.syndromeX_translate
#print axioms QLDPC.GBCode.syndromeZ_translate

-- F3: decoder-output certification
#print axioms QLDPC.DecoderCert.checkSyndromeZ_iff_dense
#print axioms QLDPC.DecoderCert.checkWeight_iff
#print axioms QLDPC.DecoderCert.checkSuccessWitness_sound
#print axioms QLDPC.DecoderCert.success_witness_syndrome
#print axioms QLDPC.DecoderCert.dot2_xStab
#print axioms QLDPC.DecoderCert.checkFailureWitness_sound
#print axioms QLDPC.DecoderCert.witness_exclusive
#print axioms QLDPC.DecoderCert.validateRun_sound
#print axioms QLDPC.DecoderCert.exampleRun_valid

-- Stage A: packed (kernel-fast) certificates
#print axioms QLDPC.Packed.unpack_xor
#print axioms QLDPC.Packed.parityAux_eq_bitSum
#print axioms QLDPC.Packed.pshift_testBit
#print axioms QLDPC.Packed.unpack_pMulVecT
#print axioms QLDPC.Packed.unpack_pMulVecS
#print axioms QLDPC.Packed.pDot_eq_dotF2
#print axioms QLDPC.Packed.pValidateRun_sound_transfer

-- Stage B: verified word-level RTL circuits
#print axioms QLDPC.RTL.circuits_eq_pValidateRun_inl
#print axioms QLDPC.RTL.circuits_eq_pValidateRun_inr
