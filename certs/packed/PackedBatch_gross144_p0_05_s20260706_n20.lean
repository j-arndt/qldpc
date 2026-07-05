-- Copyright (c) 2026 Justin Arndt. All rights reserved.
-- Licensed under the GNU GPLv3. For commercial licensing and proprietary
-- hardware mapping, see the LICENSE file (dual-licensing notice at top).
/-
  IRONCLAD-QLDPC PACKED batch certificate — gross144_p0_05_s20260706_n20
  20 decode runs on gross144, validated by the
  kernel-fast packed validator (proofs/PackedCert.lean). Soundness: each
  accepted run satisfies pValidateRun_sound_transfer, hence all conclusions
  of DecoderCert.validateRun_sound. Plain decide; zero axioms beyond the
  standard three; no native_decide.
-/

import proofs.PackedCert

set_option maxRecDepth 16384

namespace PackedBatch_gross144_p0_05_s20260706_n20

-- code instance: QLDPC.grossCode (proofs/BBCode.lean)

def run0 : QLDPC.Packed.PackedRun := ⟨2967854558970294305152, 368952966241444691968, 4611826755915743744, 368952966241444691968, 4611826755915743744, Sum.inl 0⟩
theorem cert_valid_0 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run0 = true := by decide
#print axioms cert_valid_0

def run1 : QLDPC.Packed.PackedRun := ⟨4155758480900110721312, 39199331156632799232, 11259273946431488, 39199331156632799232, 11259273946431488, Sum.inl 0⟩
theorem cert_valid_1 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run1 = true := by decide
#print axioms cert_valid_1

def run2 : QLDPC.Packed.PackedRun := ⟨2778109043505441013768, 2951479051795675742209, 147573952589676412928, 2951479051795675742209, 147573952589676412928, Sum.inl 0⟩
theorem cert_valid_2 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run2 = true := by decide
#print axioms cert_valid_2

def run3 : QLDPC.Packed.PackedRun := ⟨1328165574408780972178, 137443148928, 0, 137443148928, 0, Sum.inl 0⟩
theorem cert_valid_3 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run3 = true := by decide
#print axioms cert_valid_3

def run4 : QLDPC.Packed.PackedRun := ⟨3063447827516756369511, 2097697, 72620546281439236, 2097697, 72620546281439236, Sum.inl 0⟩
theorem cert_valid_4 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run4 = true := by decide
#print axioms cert_valid_4

def run5 : QLDPC.Packed.PackedRun := ⟨1203747018973486056960, 296300826683963867136, 110689471641646268416, 296300826683963867136, 110689471641646268416, Sum.inl 0⟩
theorem cert_valid_5 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run5 = true := by decide
#print axioms cert_valid_5

def run6 : QLDPC.Packed.PackedRun := ⟨301058879690276614336, 9223372036854775808, 16640, 9223372036854775808, 16640, Sum.inl 0⟩
theorem cert_valid_6 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run6 = true := by decide
#print axioms cert_valid_6

def run7 : QLDPC.Packed.PackedRun := ⟨4832100354, 34359738368, 524288, 34359738368, 524288, Sum.inl 0⟩
theorem cert_valid_7 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run7 = true := by decide
#print axioms cert_valid_7

def run8 : QLDPC.Packed.PackedRun := ⟨95454088845812335177, 2305843009347911744, 19439366118047872, 2305843009347911744, 19439366118047872, Sum.inl 0⟩
theorem cert_valid_8 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run8 = true := by decide
#print axioms cert_valid_8

def run9 : QLDPC.Packed.PackedRun := ⟨2598576991435269136, 18446744073709617152, 8589934592, 18446744073709617152, 8589934592, Sum.inl 0⟩
theorem cert_valid_9 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run9 = true := by decide
#print axioms cert_valid_9

def run10 : QLDPC.Packed.PackedRun := ⟨1864330403206429433899, 144115737831669777, 32770, 144115737831669777, 32770, Sum.inl 0⟩
theorem cert_valid_10 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run10 = true := by decide
#print axioms cert_valid_10

def run11 : QLDPC.Packed.PackedRun := ⟨336076726380267572224, 2361183382172310962176, 4611826756721049600, 2361183382172310962176, 4611826756721049600, Sum.inl 0⟩
theorem cert_valid_11 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run11 = true := by decide
#print axioms cert_valid_11

def run12 : QLDPC.Packed.PackedRun := ⟨1185239372675766288544, 147573954788699668480, 9223374235919974400, 147573954788699668480, 9223374235919974400, Sum.inl 0⟩
theorem cert_valid_12 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run12 = true := by decide
#print axioms cert_valid_12

def run13 : QLDPC.Packed.PackedRun := ⟨885452722738521444352, 16777216, 1180591902192388014080, 16777216, 1180591902192388014080, Sum.inl 0⟩
theorem cert_valid_13 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run13 = true := by decide
#print axioms cert_valid_13

def run14 : QLDPC.Packed.PackedRun := ⟨738157995527919137032, 274877923328, 40976, 274877923328, 40976, Sum.inl 0⟩
theorem cert_valid_14 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run14 = true := by decide
#print axioms cert_valid_14

def run15 : QLDPC.Packed.PackedRun := ⟨56565223208247624451, 0, 2305844246164276228, 0, 2305844246164276228, Sum.inl 0⟩
theorem cert_valid_15 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run15 = true := by decide
#print axioms cert_valid_15

def run16 : QLDPC.Packed.PackedRun := ⟨72058143995069473, 0, 144115188344291330, 0, 144115188344291330, Sum.inl 0⟩
theorem cert_valid_16 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run16 = true := by decide
#print axioms cert_valid_16

def run17 : QLDPC.Packed.PackedRun := ⟨147574058147099050052, 34360000512, 140737489412096, 34360000512, 140737489412096, Sum.inl 0⟩
theorem cert_valid_17 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run17 = true := by decide
#print axioms cert_valid_17

def run18 : QLDPC.Packed.PackedRun := ⟨27670573510775881858, 2251877123104768, 36893488151714070528, 2251877123104768, 36893488151714070528, Sum.inl 0⟩
theorem cert_valid_18 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run18 = true := by decide
#print axioms cert_valid_18

def run19 : QLDPC.Packed.PackedRun := ⟨844429627754496, 0, 1125900443713536, 0, 1125900443713536, Sum.inl 0⟩
theorem cert_valid_19 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run19 = true := by decide
#print axioms cert_valid_19

end PackedBatch_gross144_p0_05_s20260706_n20
