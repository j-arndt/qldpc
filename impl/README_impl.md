# IRONCLAD-QLDPC Reference Implementation

The open, unverified half of the verified-verifier architecture: a structure-exploiting
BP+OSD decoder for bivariate bicycle (BB) quantum LDPC codes, an HMAC-SHA256 audit
chain, and a certificate generator whose output is re-verified by the **Lean 4 kernel**
against the machine-checked theorems in `../proofs/` (see `DecoderCert.lean`).

Trust model in one line: **the decoder heuristic need not be trusted** — every
decode run's claims (syndrome consistency of the correction and the injected error,
residual in ker H_Z, plus the logical success/failure outcome) are certified by
witnesses that Lean's kernel re-checks with plain `decide` (zero added axioms, zero
`native_decide`), and the execution transcript is HMAC-chained (tamper-evident
*under a secret key*) to the SHA256 of the exact checker sources and certificates.
What remains in the trusted base: the Lean kernel + mathlib, the correspondence
between the in-repo polynomial supports and the physical BB codes (a human-checked
convention, cross-validated in `crosscheck.py` against an independent dense
construction), and the integrity of recorded run data (binding records to physical
hardware is out of scope).

## Layout

| File | Role |
|---|---|
| `codes.py` | BB code registry ([[72,12,6]], [[90,8,10]], [[108,8,10]], [[144,12,12]] "gross", [[288,12,18]]); dense/CSR parity checks built from the convolution definition |
| `structured.py` | Roll-based (numpy + JAX-jitted) syndrome/stabilizer maps — the circulant structure turns sparse gather/scatter into whole-array rolls; conventions match `proofs/BBCode.lean` exactly |
| `crosscheck.py` | **Acceptance gate**: dense/CSR/numpy-roll/JAX-roll agreement, CSS validity, logical counts, two-sided witness sanity — run this first |
| `logical.py` | GF(2) linear algebra + `logical_witness`: success (stabilizer combination `w`, `H_Xᵀw = r`) or failure (logical `z`, `H_X z = 0`, `⟨z,r⟩ = 1`) — mirrors `DecoderCert.lean` |
| `decoder.py` | Batched normalized min-sum BP (messages move by rolls on the torus) + OSD-0 fallback. Heuristic, outside the firewall, unverified **by design** |
| `audit/chain.py` | HMAC-SHA256 hash-chained JSONL audit log (base-repo schema, extended events); `audit/verify_chain.py` re-verifies any chain |
| `certgen.py` | Emits per-run Lean certificates to `../certs/` and kernel-checks them via `lake env lean` |
| `bench.py` | Timing + accuracy suites; every accuracy point audit-chained; sampled runs kernel-certified |

## Reproduce

```bash
# prerequisites: python3 + `pip install -r requirements.txt`; Lean toolchain per ../lean-toolchain
# (elan; first build fetches the mathlib cache: cd .. && lake exe cache get && lake build)

cd impl
python3 crosscheck.py          # acceptance gate -- must print ALL CODES, ALL CHECKS PASSED
python3 decoder.py             # decoder smoke test
python3 certgen.py --code code72   --p 0.02 --seed 3  --outcome success
python3 certgen.py --code code72   --p 0.06 --seed 11 --outcome failure
python3 certgen.py --code gross144 --p 0.02 --seed 5  --outcome success
python3 bench.py --suite all   # full suite: ~15-25 min CPU; plots+JSON in results/
python3 audit/verify_chain.py results/audit_bench.jsonl
```

Seeds are fixed in-source (`SEED` constants); all results are deterministic given the
same numpy/scipy versions. Set `IRONCLAD_HMAC_KEY` for a private audit key (the dev
key is public and marked as such in-chain).

## Honesty notes (read before quoting numbers)

- **Noise model**: code-capacity iid X errors. No measurement noise, no circuit-level
  noise. The certification layer is noise-model-agnostic; the accuracy numbers are not.
- **Timings**: CPU-only, same-machine relative comparisons. They support the scaling
  *shape* (per-syndrome-bit work independent of n for the structured path), not
  absolute hardware claims.
- **"Success"** means stabilizer-equivalence of the correction to the injected error
  (standard code-capacity criterion), certified per-run by a witness the Lean kernel
  re-checks. **"Failure" is equally certified** (anticommuting logical witness) — a
  decoder failure here is a machine-verified mathematical fact, not a statistic.
- The decoder itself (BP+OSD-0) is heuristic and deliberately unverified; only its
  **outputs** are certified. No convergence or threshold claims are made, formally or
  informally, beyond the plotted measurements with their Wilson intervals.
