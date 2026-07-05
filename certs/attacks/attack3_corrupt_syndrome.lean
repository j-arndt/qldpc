-- Copyright (c) 2026 Justin Arndt. All rights reserved.
-- Licensed under the GNU GPLv3. For commercial licensing and proprietary
-- hardware mapping, see the LICENSE file (dual-licensing notice at top).
/- ADVERSARIAL TEST 3 (grader): run0 valid, but the observed syndrome has bit0
   flipped (1216421904 -> 1216421905). The correction no longer reproduces the
   observed syndrome, so checkSyndromeZ fails. Kernel must REJECT. -/
import proofs.PackedCert
set_option maxRecDepth 16384
namespace ATTACK3
def run : QLDPC.Packed.PackedRun := ⟨1216421905, 536936448, 268439552, 536936448, 268439552, Sum.inl 0⟩
theorem cert_valid : QLDPC.Packed.pValidateRun QLDPC.code72 run = true := by decide
end ATTACK3
