/- ADVERSARIAL PROBE 4 (grader): run0 valid (residual 0), but the SUCCESS witness
   carries a garbage high bit: Sum.inl (2^40). Since `w` has NO bounds guard in
   pValidateRun, this probes whether an unbounded witness can (a) cause UNSOUNDNESS
   or (b) is harmless. Expectation from the transfer proof: unpack ignores bits
   >= 2^(l*m), and pMulVecT masks the row-rotation modulo 2^(l*m), so this should
   still validate CORRECTLY (residual is genuinely the zero stabilizer). Accepting
   here is SOUND (existential witness); the semantic conclusion is about unpack w. -/
import proofs.PackedCert
set_option maxRecDepth 16384
namespace ATTACK4
def run : QLDPC.Packed.PackedRun := ⟨1216421904, 536936448, 268439552, 536936448, 268439552, Sum.inl 1099511627776⟩
theorem cert_valid : QLDPC.Packed.pValidateRun QLDPC.code72 run = true := by decide
end ATTACK4
