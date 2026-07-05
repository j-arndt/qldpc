# qldpc

**Kernel-checked certification of quantum LDPC decoder outputs.**
The decoder stays heuristic and untrusted — every decode *outcome* is certified by a
witness that a **Lean 4-verified checker** validates, at ~0.3 s per run, with a
proof chain that extends down to **measured, synthesizable RTL**.

![License](https://img.shields.io/badge/license-Apache--2.0-blue)
![Lean](https://img.shields.io/badge/Lean-4.28.0%20%2B%20mathlib-blueviolet)
![Proofs](https://img.shields.io/badge/proofs-0%20sorries%20·%20standard%20axioms%20only-brightgreen)
![Certificates](https://img.shields.io/badge/certificates-two--sided%20·%20~0.3s%2Frun-brightgreen)
![RTL](https://img.shields.io/badge/RTL-1k--2k%20gates%20·%20depth%20≈10-informational)

Targets the **bivariate bicycle (BB) codes** on current fault-tolerance hardware
roadmaps — [[72,12,6]] through [[288,12,18]], including IBM's [[144,12,12]] "gross"
code.

```
        untrusted / heuristic          │        verified / kernel-checked
                                       │
   BP+OSD decoder ──── correction ────►│──► witness extraction (GF(2))
   (impl/decoder.py)                   │        │
                                       │        ▼
   noise sampling, benchmarks          │    packed Lean certificate (certs/)
   (impl/bench.py)                     │    checked by plain `decide` — no axioms
                                       │    beyond propext + Quot.sound
        HMAC-SHA256 audit chain ◄──────┴────────┘
        (impl/audit/) — pins checker sources + certificates + kernel verdicts
```

## Sixty-second tour

```bash
# proofs: zero errors, zero warnings, zero sorries — and a machine-printed axiom audit
lake exe cache get && lake build
lake build proofs.AxiomAudit

# pipeline: acceptance gate, then certify 24 live decode runs in ONE kernel check
cd impl && pip install -r requirements.txt
python3 crosscheck.py
python3 -c "import certgen, json; print(json.dumps(certgen.certify_batch('gross144', 0.06, 24, 1), indent=2))"

# the checker cannot be fooled: 3 forged certificates rejected, 1 soundness probe accepted
cd .. && bash certs/attacks/run_attacks.sh

# Stage B: regenerate the Verilog from Lean and verify it against ground truth
lake env lean scripts/EmitRTL.lean && cd impl && python3 rtl_equiv.py
```

## What's in the box

| Path | What it is |
|---|---|
| `proofs/` | Six Lean files, all theorems machine-checked (table below) |
| `impl/` | Reference BP+OSD decoder, GF(2) witness extraction, HMAC audit chain, certificate generator, RTL equivalence harness |
| `certs/` | Kernel-checked run certificates — single-run, **packed batches**, and the **forgery-attack demos** (`certs/attacks/`) |
| `rtl/` | Synthesizable Verilog + JSON netlists **emitted from Lean**, plus the measured gate report |
| `scripts/` | `EmitRTL.lean` — regenerates `rtl/` deterministically |
| `ci/` | CI configs (copy to `.github/workflows/` to activate — see below) |

## What is proven (Lean 4 v4.28.0 + mathlib)

| File | Theorems |
|---|---|
| `proofs/QCCirculant.lean` | **T1/T1ᵀ** sparse evaluation (O(row-weight) work per bit) = dense circulant action; F₂ pairing adjointness; translation equivariance |
| `proofs/BBCode.lean` | **T2** CSS validity `H_X · H_Zᵀ = 0` proven **parametrically for the whole two-block group-algebra family at once**; sparse = dense syndrome bridges; **T3** translation equivariance of the syndrome maps; gross + [[72,12,6]] instances |
| `proofs/DecoderCert.lean` | **T4** syndrome-checker soundness against dense semantics; **T6/T7** two-sided witness soundness (success: residual is a stabilizer; failure: residual provably is NOT); **T8** exclusivity; `validateRun_sound` master theorem incl. residual ∈ ker H_Z (failure = undetectable non-stabilizer = logical error) |
| `proofs/PackedCert.lean` | **Stage A**: Nat-bitmask packed checker (pure GMP-accelerated kernel arithmetic) with proven torus-shift bit specs and the **master transfer theorem** — accepted packed certificates inherit every conclusion of `validateRun_sound` |
| `proofs/Netlist.lean` | **Stage B**: word-level RTL language whose primitive semantics are the proven packed ops; `circuits_eq_pValidateRun_{inl,inr}` — the emitted circuit **is** the packed validator; Verilog/JSON printers (trusted-printer boundary stated in-file) |
| `proofs/AxiomAudit.lean` | Machine-printed axiom footprint of every theorem above — Stage A/B need only `[propext, Quot.sound]` |

**Two-sided certification is the point.** Success is witnessed by an explicit
stabilizer combination (`H_Xᵀw = r`); **failure** is witnessed by an explicit
anticommuting logical (`H_X z = 0`, `⟨z,r⟩ = 1`). A decoder failure becomes a
kernel-checked mathematical fact, not a statistic — and no run can carry both
certificates (proven).

## Measured results (not theorems — see honesty box)

| Metric | Value |
|---|---|
| Packed certificate cost | **≈0.26–0.4 s per run marginal** (24-run gross batch incl. a failure cert: 48 s total); semantic single-run form: 34–65 s |
| Checker circuit size | **1,038 gates @ depth ≈10** ([[72,12,6]]) · **2,082 gates @ depth ≈11** ([[144,12,12]]) — from the Lean-emitted netlists |
| Syndrome evaluation (CPU, batch 256) | structured rolls **17–79× vs dense**, **13–33× vs a fair fully-batched FFT** |
| BP throughput (CPU) | ~103k iters/s (n=72) → ~34k (n=288) |
| Logical error rate | code-capacity iid-X curves for [[72]]/[[90]]/[[144]] with Wilson 95% intervals — JSON in `impl/results/` (plots regenerate via `bench.py`), every point HMAC-chained |
| Forgery resistance | `certs/attacks/`: garbage high bits, forged success witness, corrupted syndrome — **all rejected by the kernel**; one unbounded-but-sound witness probe correctly accepted |

## Honesty box (read before quoting)

- The **decoder is not verified — by design** (certifying-algorithms paradigm,
  McConnell–Mehlhorn–Näher–Schweitzer). No convergence, threshold, or performance
  theorems exist here; BP+OSD-0 is a reference decoder, below state of the art.
- Accuracy numbers are **code-capacity iid-X only**; no measurement/circuit noise.
- Certificates certify the **recorded** run data; binding records to physical
  hardware events (attested I/O) is out of scope.
- The audit chain is tamper-evident **under a secret HMAC key**; the demo chain uses
  a disclosed dev key (and says so in its own genesis record). Its real guarantee is
  **independent re-verifiability**: it pins every artifact a third party needs —
  `verify_chain.py --recheck-certs`, then re-run `lake env lean` on any pinned cert.
- Failure witnesses require the injected error — i.e. simulation / injected-error
  audit campaigns; in production, syndrome-consistency certificates apply per shot.
- Stage B's Verilog/JSON **printers are trusted** (≈100 lines; boundary stated in
  `proofs/Netlist.lean`); the emitted netlist is independently verified by exact
  matrix equality against a from-scratch dense construction, live-run behavioural
  checks, and a printer cross-check (`impl/rtl_equiv.py`).
- Trusted base: the Lean kernel + mathlib, and the human-checked correspondence
  between the in-repo polynomial supports and the physical BB codes
  (cross-validated four independent ways in `impl/crosscheck.py`).

## Full reproduction

```bash
# 1. Lean toolchain + proofs
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh
lake exe cache get && lake build           # zero errors, zero warnings
lake build proofs.AxiomAudit               # prints every theorem's axiom footprint

# 2. Python pipeline
cd impl && pip install -r requirements.txt
python3 crosscheck.py                      # acceptance gate: ALL CODES, ALL CHECKS PASSED
python3 bench.py --suite all               # ~5 min CPU: timings, LER curves, audit chain
python3 audit/verify_chain.py --recheck-certs .. results/audit_bench.jsonl

# 3. Certify decode runs yourself
python3 certgen.py --code gross144 --p 0.02 --seed 42                     # single run
python3 -c "import certgen, json; print(json.dumps(certgen.certify_batch('gross144', 0.06, 24, 1), indent=2))"  # batch

# 4. Stage B round-trip
cd .. && lake env lean scripts/EmitRTL.lean && cd impl && python3 rtl_equiv.py
```

All seeds fixed in-source; results deterministic given the same numpy/scipy.

## Roadmap

The endgame is **per-shot certification at line rate with a verified checker in
hardware** — see [ROADMAP.md](ROADMAP.md). Stage A (kernel-fast packed checker) and
Stage B (verified word-level RTL, within the stated trusted-printer boundary) are
**complete in this repository**; the measured checker is 1–2k two-input gates at
depth ~10, so the hardware endgame's complexity budget is confirmed, not estimated.
Next: bitstream attestation (Stage C), checker on the syndrome bus (Stage D), plus
production-decoder integration and circuit-level noise.

## Provenance & positioning

Grew out of the [ironclad](https://github.com/j-arndt/ironclad) verification
sandbox; the certification layer here is self-contained and depends only on
mathlib. Adversarially reviewed in fresh-context audit rounds before release;
hand-built bogus certificates are **rejected by the Lean kernel**, as the
soundness theorems require (see `certs/attacks/`).

Nearby work: [Lean-QEC](https://arxiv.org/abs/2605.16523) certifies *static* code
properties (minimum distance) for the same code families — complementary to
run-level decoder-output certification. Infotheo (Coq) verified *classical* LDPC
sum-product decoding. Hash-chain notarization of opaque quantum outputs (e.g.
Λ-Spira) pins custody but not machine-checked semantics.

## Continuous integration

CI configs live in [`ci/`](ci/): the Lean job builds all proofs and **fails on any
`sorry` or any non-standard axiom**; the Python job runs the acceptance gate, the
RTL equivalence harness, and the audit chain self-test. To activate, copy them to
`.github/workflows/` in your clone (the automated release path cannot write to
that directory).

## Citing

See [CITATION.cff](CITATION.cff). Python package name: `qldpc-cert`
([pyproject.toml](pyproject.toml)).

## License

Apache License 2.0 — see [LICENSE](LICENSE).
