# qldpc — Kernel-Checked Certification of QLDPC Decoder Outputs

Formally verified, cryptographically audited certification of decoder outputs for
**bivariate bicycle (BB) quantum LDPC codes** — the code family on current
fault-tolerance hardware roadmaps ([[72,12,6]] through [[288,12,18]], including
IBM's [[144,12,12]] "gross" code).

**The architecture in one line:** the decoder stays heuristic and untrusted; every
decode *outcome* is certified by a witness that a **formally verified checker**
validates, the checker's soundness theorems are machine-checked in **Lean 4**, and
every run is bound into an **HMAC-SHA256 audit chain** that pins the exact checker
sources it was certified against.

```
        untrusted / heuristic          │        verified / kernel-checked
                                       │
   JAX BP+OSD decoder ── correction ──►│──► witness extraction (GF(2))
   (impl/decoder.py)                   │        │
                                       │        ▼
   noise sampling, benchmarks          │    per-run Lean certificate (certs/)
   (impl/bench.py)                     │    checked by plain `decide` — zero axioms
                                       │        │
        HMAC-SHA256 audit chain ◄──────┴────────┘
        (impl/audit/) — records checker-source hashes + kernel verdicts
```

**This repository builds 100% clean: zero `sorry`s, zero project axioms, zero
`native_decide`, zero warnings.** `lake build proofs.AxiomAudit` machine-prints the
axiom footprint of every theorem (`propext`, `Classical.choice`, `Quot.sound` only).

## What is proven (Lean 4 v4.28.0 + mathlib)

| File | Theorems |
|---|---|
| `proofs/QCCirculant.lean` | **T1/T1ᵀ** sparse evaluation (O(row-weight) work per bit) = dense circulant action; F₂ pairing adjointness; translation equivariance of sparse evaluation |
| `proofs/BBCode.lean` | **T2** CSS validity `H_X · H_Zᵀ = 0` proven **parametrically for the whole two-block group-algebra family at once** (any finite abelian group, any polynomial pair); sparse = dense syndrome bridges; **T3** syndrome maps commute with qubit translations; gross + [[72,12,6]] instances |
| `proofs/DecoderCert.lean` | **T4** syndrome-checker soundness against dense semantics; **T6** success-witness soundness (residual is a stabilizer); **T7** failure-witness soundness (residual provably NOT a stabilizer); **T8** exclusivity — no run can carry both certificates; `validateRun_sound` master theorem incl. **residual ∈ ker H_Z** conjunct (failure = undetectable non-stabilizer = logical error); named end-to-end `decide` theorem. (A decidable weight predicate is provided as a utility — not part of the certified pipeline.) |
| `proofs/PackedCert.lean` | **Stage A**: Nat-bitmask packed representation with unpacking theorems; proven torus-shift bit specs; fuel-structural parity = F₂ bit-sum; `pValidateRun` (pure GMP-accelerated kernel arithmetic) + **master transfer theorem** — every accepted packed certificate satisfies all of `validateRun_sound`'s conclusions |
| `proofs/Netlist.lean` | **Stage B**: word-level RTL language whose primitive semantics are the proven packed ops; three checker circuits (production syndrome check; audit success/failure witnesses); `circuits_eq_pValidateRun_{inl,inr}` — the circuit conjunction IS the packed validator; bit-blasted Verilog + JSON emission (trusted printer, boundary stated in-file) |
| `proofs/AxiomAudit.lean` | Machine-recorded axiom footprint of every theorem above (Stage A/B theorems need only `[propext, Quot.sound]`) |

**Two-sided certification** is the point: decoding **success** is witnessed by an
explicit stabilizer combination (`H_Xᵀ w = r`), decoding **failure** by an explicit
anticommuting logical (`H_X z = 0`, `⟨z,r⟩ = 1`) — so a decoder failure is a
kernel-checked mathematical fact, not a statistic. Measured certificate check
times (CPU, plain `decide`): semantic single-run certs 34–65 s; **Stage A packed
batch certs ≈0.26–0.4 s per run marginal** (24-run gross-code batch incl. a
failure certificate: 48 s total — one mathlib import amortized over the batch).
Every emitted certificate carries named theorems plus `#print axioms`, so each
certificate self-reports its own axiom footprint into the audit record.

## What is measured (not claimed as theorems)

- Syndrome evaluation via structured rolls: **17–79× faster than dense** matvec and
  **13–33× faster than a fair, fully-batched FFT baseline** at n = 72–288, with
  near-linear scaling (CPU, batch 256, medians; see `impl/results/`).
- BP throughput: ~103k iterations/s (n=72) → ~34k (n=288), batched CPU.
- Code-capacity logical-error curves (iid X, BP60+OSD-0, Wilson 95% intervals) for
  [[72,12,6]], [[90,8,10]], [[144,12,12]] — every point recorded in a verified
  HMAC audit chain; sampled runs additionally kernel-certified.
- **Stage B gate report** (from the Lean-emitted netlists, `impl/rtl_equiv.py`):
  full four-output checker ≈ **1,038 two-input gates, depth ≈10** ([[72,12,6]])
  and **2,082 gates, depth ≈11** ([[144,12,12]]) — the ROADMAP's "~10³ gates"
  estimate, measured. All linear layers verified by **exact matrix equality**
  against the independent dense construction (complete, not sampled).

## Honesty box (read before quoting)

- The decoder is **not** verified — by design (certifying-algorithms paradigm,
  McConnell–Mehlhorn–Näher–Schweitzer). No convergence, threshold, or
  decoder-performance theorems exist here. BP+OSD-0 is a reference decoder, below
  state of the art.
- Accuracy numbers are **code-capacity iid-X only**; no measurement/circuit noise.
- Certificates certify the **recorded** run data; binding records to physical
  hardware events (attested I/O) is out of scope.
- The audit chain is tamper-evident **under a secret HMAC key**; the demo chain
  uses a disclosed dev key (and says so in its own genesis record). Its real
  guarantee is that it pins every artifact (checker sources, certificates) a third
  party needs to **re-verify independently**: `verify_chain.py --recheck-certs`,
  then re-run `lake env lean` on any pinned certificate.
- Failure witnesses require the injected error — i.e. simulation / injected-error
  audit campaigns; in production, syndrome-consistency certificates apply per-run.
- Certificate checking is on-demand (~40 s each via plain `decide`), not real-time.
- Trusted base: the Lean kernel + mathlib, and the correspondence between the
  in-repo polynomial supports and the physical BB codes (a human-checked convention,
  cross-validated in `impl/crosscheck.py` against an independent dense construction).

## Reproduce everything

```bash
# 1. Lean toolchain + proofs
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh
lake exe cache get && lake build           # zero errors, zero warnings
lake build proofs.AxiomAudit               # prints every theorem's axiom footprint

# 2. Python pipeline
cd impl && pip install -r requirements.txt
python3 crosscheck.py                      # acceptance gate: ALL CODES, ALL CHECKS PASSED
python3 bench.py --suite all               # ~5 min CPU: timings, LER curves, audit chain,
                                           #   kernel-checked certificates
python3 audit/verify_chain.py --recheck-certs .. results/audit_bench.jsonl

# 3. Certify a fresh decode run yourself (semantic single-run form)
python3 certgen.py --code gross144 --p 0.02 --seed 42

# 4. Stage A: batch-certify 24 runs in ONE kernel check (~0.3 s/run marginal)
python3 -c "import certgen, json; print(json.dumps(certgen.certify_batch('gross144', 0.06, 24, 1), indent=2))"

# 5. Stage B: emit RTL from Lean and run the equivalence harness
cd .. && lake env lean scripts/EmitRTL.lean && cd impl && python3 rtl_equiv.py
```

## Provenance & positioning

This work grew out of the [ironclad](https://github.com/j-arndt/ironclad)
verification sandbox (circulant block-diagonal algebra + HMAC audit chains); the
QLDPC certification layer here is self-contained and depends only on mathlib.
Development was adversarially reviewed in two fresh-context audit rounds before
release; among other checks, hand-built bogus certificates (forged witnesses,
misreported syndromes) are **rejected by the Lean kernel**, as the soundness
theorems require.

Positioning relative to nearby work: [Lean-QEC](https://arxiv.org/abs/2605.16523)
certifies *static* code properties (minimum distance) for the same code families —
complementary to run-level decoder-output certification; Infotheo (Coq) verified
*classical* LDPC sum-product decoding; hash-chain notarization of opaque quantum
outputs (e.g. Λ-Spira) pins custody but not machine-checked semantics.

## Roadmap

Where this goes: per-shot certification at microsecond scale with a verified
checker compiled to hardware — see [ROADMAP.md](ROADMAP.md). **Stage A (kernel-fast
packed checker) and Stage B (verified word-level RTL + emitted Verilog, within the
stated trusted-printer boundary) are complete in this repository**; the measured
checker is ~1–2k two-input gates at depth ~10, so the hardware endgame's
complexity budget is confirmed, not estimated.

## Continuous integration

CI configs live in [`ci/`](ci/) (`ci/lean.yml`, `ci/python.yml`): the Lean job
builds all proofs and **fails on any `sorry` or any non-standard axiom**; the
Python job runs the acceptance gate, the RTL equivalence harness, and the audit
chain self-test. To activate, copy them to `.github/workflows/` in your clone
(they ship under `ci/` because the automated release path cannot write to
`.github/workflows/`).

## License

Apache License 2.0 — see [LICENSE](LICENSE).
