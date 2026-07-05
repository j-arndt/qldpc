-- Copyright (c) 2026 Justin Arndt. All rights reserved.
-- Licensed under the GNU GPLv3. For commercial licensing and proprietary
-- hardware mapping, see the LICENSE file (dual-licensing notice at top).
/- ADVERSARIAL TEST 1 (grader): run0 from the valid code72 batch, but corr1 has a
   garbage bit set at position 40 (>= 2^36 = M). The bounds guard `decide (corr1 < M)`
   in pValidateRun must make the validator return FALSE, so `= true` must NOT type-check.
   Baseline valid run0: ⟨1216421904, 536936448, 268439552, 536936448, 268439552, Sum.inl 0⟩
   Here corr1 = 536936448 + 2^40 = 1100048564224. -/
import proofs.PackedCert
set_option maxRecDepth 16384
namespace ATTACK1
def run : QLDPC.Packed.PackedRun := ⟨1216421904, 1100048564224, 268439552, 536936448, 268439552, Sum.inl 0⟩
theorem cert_valid : QLDPC.Packed.pValidateRun QLDPC.code72 run = true := by decide
end ATTACK1
