-- Copyright (c) 2026 Justin Arndt. All rights reserved.
-- Licensed under the GNU GPLv3. For commercial licensing and proprietary
-- hardware mapping, see the LICENSE file (dual-licensing notice at top).
/- ADVERSARIAL TEST 2 (grader): run4 is a genuine FAILURE run (nonzero residual,
   Sum.inr witness). Here we forge a SUCCESS claim with the zero witness Sum.inl 0.
   xStab(0) = (0,0) but the residual r2 = corr2 ^ inj2 = 105382146 ^ 155714562 != 0,
   so checkSuccessWitness fails. Kernel must REJECT. -/
import proofs.PackedCert
set_option maxRecDepth 16384
namespace ATTACK2
def run : QLDPC.Packed.PackedRun := ⟨9374007666, 8, 105382146, 8, 155714562, Sum.inl 0⟩
theorem cert_valid : QLDPC.Packed.pValidateRun QLDPC.code72 run = true := by decide
end ATTACK2
