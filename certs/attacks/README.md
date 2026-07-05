# Forgery-rejection demonstrations

Concrete evidence that the verified packed checker (`proofs/PackedCert.lean`,
`pValidateRun` + `pValidateRun_sound_transfer`) cannot be fooled. Each file is a
hand-built `PackedRun` fed to `pValidateRun ... = true := by decide`; the Lean
kernel's verdict is the test.

| File | Tampering | Expected |
|---|---|---|
| `attack1_garbage_highbit.lean` | valid run, but `corr1` carries a garbage bit ≥ 2^(ℓ·m) | **REJECT** (bounds guard) |
| `attack2_forged_success.lean` | genuine failure run re-labelled `Sum.inl 0` (zero success witness) | **REJECT** (`H_Xᵀ0 ≠ r`) |
| `attack3_corrupt_syndrome.lean` | valid run, one observed-syndrome bit flipped | **REJECT** (syndrome check) |
| `attack4_garbage_witness_sound.lean` | valid zero-residual run, success witness has an unbounded high bit | **ACCEPT** — SOUND: `unpack` ignores bits ≥ 2^(ℓ·m) and `pMulVecT` masks mod 2^(ℓ·m), so the witness still denotes the zero stabilizer. The semantic conclusion of the transfer theorem is about `unpack w`, so accepting here is correct, not a leak. |

Run all four:

```bash
bash certs/attacks/run_attacks.sh   # asserts 3 REJECT + 1 ACCEPT
```

Attacks 1–3 are *supposed* to make `decide` fail — a `lake env lean` on them
prints a `decide` error, which is the point. Attack 4 type-checks. The runner
script encodes the expected outcome for each and exits nonzero on any surprise.
