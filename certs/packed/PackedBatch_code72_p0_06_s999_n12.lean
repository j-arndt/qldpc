-- Copyright (c) 2026 Justin Arndt. All rights reserved.
-- Licensed under the GNU GPLv3. For commercial licensing and proprietary
-- hardware mapping, see the LICENSE file (dual-licensing notice at top).
/-
  IRONCLAD-QLDPC PACKED batch certificate — code72_p0_06_s999_n12
  12 decode runs on code72, validated by the
  kernel-fast packed validator (proofs/PackedCert.lean). Soundness: each
  accepted run satisfies pValidateRun_sound_transfer, hence all conclusions
  of DecoderCert.validateRun_sound. Plain decide; zero axioms beyond the
  standard three; no native_decide.
-/

import proofs.PackedCert

set_option maxRecDepth 16384

namespace PackedBatch_code72_p0_06_s999_n12

-- code instance: QLDPC.code72 (proofs/BBCode.lean)

def run0 : QLDPC.Packed.PackedRun := ⟨1216421904, 536936448, 268439552, 536936448, 268439552, Sum.inl 0⟩
theorem cert_valid_0 :
    QLDPC.Packed.pValidateRun QLDPC.code72 run0 = true := by decide
#print axioms cert_valid_0

def run1 : QLDPC.Packed.PackedRun := ⟨1204033280, 16777280, 335806464, 16777280, 335806464, Sum.inl 0⟩
theorem cert_valid_1 :
    QLDPC.Packed.pValidateRun QLDPC.code72 run1 = true := by decide
#print axioms cert_valid_1

def run2 : QLDPC.Packed.PackedRun := ⟨209732864, 1048576, 268435456, 1048576, 268435456, Sum.inl 0⟩
theorem cert_valid_2 :
    QLDPC.Packed.pValidateRun QLDPC.code72 run2 = true := by decide
#print axioms cert_valid_2

def run3 : QLDPC.Packed.PackedRun := ⟨8615128114, 1073938432, 524288, 1073938432, 524288, Sum.inl 0⟩
theorem cert_valid_3 :
    QLDPC.Packed.pValidateRun QLDPC.code72 run3 = true := by decide
#print axioms cert_valid_3

def run4 : QLDPC.Packed.PackedRun := ⟨9374007666, 8, 105382146, 8, 155714562, Sum.inr (50856587, 455)⟩
theorem cert_valid_4 :
    QLDPC.Packed.pValidateRun QLDPC.code72 run4 = true := by decide
#print axioms cert_valid_4

def run5 : QLDPC.Packed.PackedRun := ⟨1227425792, 8594128896, 64, 8594128896, 64, Sum.inl 0⟩
theorem cert_valid_5 :
    QLDPC.Packed.pValidateRun QLDPC.code72 run5 = true := by decide
#print axioms cert_valid_5

def run6 : QLDPC.Packed.PackedRun := ⟨17215597636, 37748752, 136, 74752, 136, Sum.inr (1310750, 0)⟩
theorem cert_valid_6 :
    QLDPC.Packed.pValidateRun QLDPC.code72 run6 = true := by decide
#print axioms cert_valid_6

def run7 : QLDPC.Packed.PackedRun := ⟨4362085424, 65540, 0, 65540, 0, Sum.inl 0⟩
theorem cert_valid_7 :
    QLDPC.Packed.pValidateRun QLDPC.code72 run7 = true := by decide
#print axioms cert_valid_7

def run8 : QLDPC.Packed.PackedRun := ⟨26038902784, 33554432, 34359738368, 33554432, 34359738368, Sum.inl 0⟩
theorem cert_valid_8 :
    QLDPC.Packed.pValidateRun QLDPC.code72 run8 = true := by decide
#print axioms cert_valid_8

def run9 : QLDPC.Packed.PackedRun := ⟨60399077666, 8390672, 34359803904, 8390672, 34359803904, Sum.inl 0⟩
theorem cert_valid_9 :
    QLDPC.Packed.pValidateRun QLDPC.code72 run9 = true := by decide
#print axioms cert_valid_9

def run10 : QLDPC.Packed.PackedRun := ⟨26575118337, 4096, 16875520, 67108880, 32772, Sum.inr (1310750, 0)⟩
theorem cert_valid_10 :
    QLDPC.Packed.pValidateRun QLDPC.code72 run10 = true := by decide
#print axioms cert_valid_10

def run11 : QLDPC.Packed.PackedRun := ⟨147705880, 2432696320, 65568, 2432696320, 65568, Sum.inl 0⟩
theorem cert_valid_11 :
    QLDPC.Packed.pValidateRun QLDPC.code72 run11 = true := by decide
#print axioms cert_valid_11

end PackedBatch_code72_p0_06_s999_n12
