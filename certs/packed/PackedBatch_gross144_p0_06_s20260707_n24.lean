/-
  IRONCLAD-QLDPC PACKED batch certificate — gross144_p0_06_s20260707_n24
  24 decode runs on gross144, validated by the
  kernel-fast packed validator (proofs/PackedCert.lean). Soundness: each
  accepted run satisfies pValidateRun_sound_transfer, hence all conclusions
  of DecoderCert.validateRun_sound. Plain decide; zero axioms beyond the
  standard three; no native_decide.
-/

import proofs.PackedCert

set_option maxRecDepth 16384

namespace PackedBatch_gross144_p0_06_s20260707_n24

-- code instance: QLDPC.grossCode (proofs/BBCode.lean)

def run0 : QLDPC.Packed.PackedRun := ⟨1258017792244808941576, 147591969255928627201, 0, 147591969255928627201, 0, Sum.inl 0⟩
theorem cert_valid_0 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run0 = true := by decide
#print axioms cert_valid_0

def run1 : QLDPC.Packed.PackedRun := ⟨2368159916706339227164, 292734525534896160, 9259400833873741856, 292734525534896160, 9259400833873741856, Sum.inl 0⟩
theorem cert_valid_1 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run1 = true := by decide
#print axioms cert_valid_1

def run2 : QLDPC.Packed.PackedRun := ⟨2384350320868009246728, 297453748188834955264, 2097152, 297453748188834955264, 2097152, Sum.inl 0⟩
theorem cert_valid_2 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run2 = true := by decide
#print axioms cert_valid_2

def run3 : QLDPC.Packed.PackedRun := ⟨383369213662128775224, 1153519638949134340, 885448219137685864480, 1153519638949134340, 885448219137685864480, Sum.inl 0⟩
theorem cert_valid_3 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run3 = true := by decide
#print axioms cert_valid_3

def run4 : QLDPC.Packed.PackedRun := ⟨156797465372626526994, 1073807488, 36893488147419104256, 1073807488, 36893488147419104256, Sum.inl 0⟩
theorem cert_valid_4 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run4 = true := by decide
#print axioms cert_valid_4

def run5 : QLDPC.Packed.PackedRun := ⟨2513512996330715250755, 295147905179352830080, 288230376420147200, 295147905179352830080, 288230376420147200, Sum.inl 0⟩
theorem cert_valid_5 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run5 = true := by decide
#print axioms cert_valid_5

def run6 : QLDPC.Packed.PackedRun := ⟨222517249237568193546, 140892107178113, 4503874505277440, 140892107178113, 4503874505277440, Sum.inl 0⟩
theorem cert_valid_6 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run6 = true := by decide
#print axioms cert_valid_6

def run7 : QLDPC.Packed.PackedRun := ⟨4141375215237897273553, 295147909646655689728, 2379629986608043851776, 295147909646655689728, 2379629986608043851776, Sum.inl 0⟩
theorem cert_valid_7 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run7 = true := by decide
#print axioms cert_valid_7

def run8 : QLDPC.Packed.PackedRun := ⟨2971386688931727829536, 1254378737836174213120, 442721928140055117824, 1254378737836174213120, 442721928140055117824, Sum.inl 0⟩
theorem cert_valid_8 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run8 = true := by decide
#print axioms cert_valid_8

def run9 : QLDPC.Packed.PackedRun := ⟨77245760651669276289, 315680096320, 4611686018729377792, 315680096320, 4611686018729377792, Sum.inl 0⟩
theorem cert_valid_9 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run9 = true := by decide
#print axioms cert_valid_9

def run10 : QLDPC.Packed.PackedRun := ⟨2763697569228052234904, 9223442405598953474, 747093137184262194688, 9367557593674809348, 147573954788701767169, Sum.inl 8⟩
theorem cert_valid_10 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run10 = true := by decide
#print axioms cert_valid_10

def run11 : QLDPC.Packed.PackedRun := ⟨4210719319787896320001, 885587830726134333448, 3541774862152233926656, 885587830726134333448, 3541774862152233926656, Sum.inl 0⟩
theorem cert_valid_11 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run11 = true := by decide
#print axioms cert_valid_11

def run12 : QLDPC.Packed.PackedRun := ⟨38407482854281317636, 4656730834416451584, 34359738432, 4656730834416451584, 34359738432, Sum.inl 0⟩
theorem cert_valid_12 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run12 = true := by decide
#print axioms cert_valid_12

def run13 : QLDPC.Packed.PackedRun := ⟨1293578315403776795852, 2621473, 73787117307338686656, 2621473, 73787117307338686656, Sum.inl 0⟩
theorem cert_valid_13 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run13 = true := by decide
#print axioms cert_valid_13

def run14 : QLDPC.Packed.PackedRun := ⟨848670694887850244, 72094981728256000, 361413887276351488, 72094981728256000, 361413887276351488, Sum.inl 0⟩
theorem cert_valid_14 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run14 = true := by decide
#print axioms cert_valid_14

def run15 : QLDPC.Packed.PackedRun := ⟨2779698488752937918632, 16779265, 1187509154144172671488, 16779265, 1187509154144172671488, Sum.inl 0⟩
theorem cert_valid_15 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run15 = true := by decide
#print axioms cert_valid_15

def run16 : QLDPC.Packed.PackedRun := ⟨150024210474501160976, 18053982068932610, 70368744177664, 18053982068932610, 70368744177664, Sum.inl 0⟩
theorem cert_valid_16 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run16 = true := by decide
#print axioms cert_valid_16

def run17 : QLDPC.Packed.PackedRun := ⟨590989453521262501900, 82331430687866880, 144119586125545472, 82331430687866880, 144119586125545472, Sum.inl 0⟩
theorem cert_valid_17 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run17 = true := by decide
#print axioms cert_valid_17

def run18 : QLDPC.Packed.PackedRun := ⟨309706095868692662400, 90074329010798596, 4503599627371008, 90074329010798596, 4503599627371008, Sum.inl 0⟩
theorem cert_valid_18 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run18 = true := by decide
#print axioms cert_valid_18

def run19 : QLDPC.Packed.PackedRun := ⟨2880298815707371653124, 18446744073776660736, 295157475878316933120, 18446744073776660736, 295157475878316933120, Sum.inl 0⟩
theorem cert_valid_19 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run19 = true := by decide
#print axioms cert_valid_19

def run20 : QLDPC.Packed.PackedRun := ⟨1209910932738118583330, 73842145733875073048, 274877906946, 73842145733875073048, 274877906946, Sum.inl 0⟩
theorem cert_valid_20 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run20 = true := by decide
#print axioms cert_valid_20

def run21 : QLDPC.Packed.PackedRun := ⟨151505597278137552064, 175244068976997695488, 4132070953986218262656, 18446744358519832576, 432347763284385856, Sum.inr (90074054133022750, 0)⟩
theorem cert_valid_21 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run21 = true := by decide
#print axioms cert_valid_21

def run22 : QLDPC.Packed.PackedRun := ⟨228278493097333166144, 0, 9223372036871565312, 0, 9223372036871565312, Sum.inl 0⟩
theorem cert_valid_22 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run22 = true := by decide
#print axioms cert_valid_22

def run23 : QLDPC.Packed.PackedRun := ⟨607654286712958095368, 74950033107293569024, 9295429631968542720, 74950033107293569024, 9295429631968542720, Sum.inl 0⟩
theorem cert_valid_23 :
    QLDPC.Packed.pValidateRun QLDPC.grossCode run23 = true := by decide
#print axioms cert_valid_23

end PackedBatch_gross144_p0_06_s20260707_n24
