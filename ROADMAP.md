# Roadmap: from 40-second certificates to accountability at line rate

The thesis of this repository is that decoder trust should come from **certified
outcomes**, not from trusting decoder internals. The current artifact proves the
architecture at reference scale: kernel-checked, two-sided per-run certificates in
~40 s. The endgame is **per-shot certification at microsecond scale with a
verified checker compiled to hardware — decoder accountability at zero marginal
latency.** This document is the honest engineering path between the two.

## Why the endgame is reachable (and not a slogan)

1. **The verified checker's intrinsic complexity is ~10³ XOR gates.** Everything
   the soundness theorems gate (syndrome consistency, stabilizer witnesses,
   anticommutation parities) is F₂-linear with constant row weight — for the
   [[144,12,12]] gross code, 72 syndrome bits × 6 XORs plus two sparse XOR trees
   and a parity. This was a design decision (theorems T1/T4 prove the sparse form
   sound), and it is why this architecture can ride to hardware while
   "verify-the-decoder" approaches cannot. In silicon the checker is nanoseconds;
   the decoder (~1 µs/round on current FPGA implementations) is always the
   bottleneck, never the accountability.

2. **The current 40 s is kernel interpretation overhead, not mathematics.** The
   Lean kernel today evaluates `Finset` sums over `Fin ℓ × Fin m` term by term.
   Lean's kernel natively accelerates `Nat` arithmetic (GMP); packing F₂ vectors
   into `Nat` bitmasks and proving the packed checker equal to the existing
   semantic definitions keeps certificates axiom-free and kernel-checked while
   evaluating at near-native speed. (Lean-QEC's BitVec-flattening exploits the
   same fact for distance certification.)

3. **The genuinely open gap is verified Lean→RTL.** Coq has prior art (Silver
   Oak/Cava; Kôika); Lean has no mature verified path to Verilog. This is the
   research-grade chunk — bounded, because the object to verify is a fixed
   XOR-tree netlist, not a general compiler.

## Stages

### Stage A — kernel-fast verified checker — ✅ COMPLETE (proofs/PackedCert.lean)
Re-express the checkers over `Nat`-packed bit vectors (`Nat.xor`, `Nat.land`,
popcount); prove packed = semantic (extending the T1/T4 bridge pattern); target
**sub-second `decide`** per certificate, plus batched certificates (N runs per
file) to amortize import cost. Deliverable: same guarantees, ~100× lower cost,
enabling certification of full test campaigns rather than sampled runs.
**Delivered**: packed validator with master transfer theorem (axioms:
propext + Quot.sound only); measured 0.26–0.4 s/run marginal in batches
(24-run gross batch incl. failure cert: 48 s total). Kernel lessons learned and
documented in-file: well-founded recursion does not kernel-reduce (parity is
fuel-structural); log2-derived fuel reintroduces WF (fuel is a width literal).

### Stage B — verified/equivalence-checked RTL — ✅ COMPLETE within stated scope (proofs/Netlist.lean + rtl/ + impl/rtl_equiv.py)
Export the packed checker as a golden model; produce RTL whose equivalence to the
model is machine-checked (SymbiYosys-style equivalence against a Lean-exported
netlist semantics, or a Cava/Kôika-inspired construction). Deliverable: a checker
bitstream with a proof chain back to the same Lean theorems in this repository.
**Delivered (scope)**: word-level RTL language with primitive semantics equal to
the proven packed operations; `circuits_eq_pValidateRun` theorems; bit-blasted
Verilog/JSON emitted from Lean (trusted printer, ~100 lines, boundary stated);
equivalence harness with EXACT matrix equality on all linear layers vs the
independent dense construction + live-run behavioural checks + printer
cross-check; measured 1,038–2,082 two-input gates at depth 10–11. Out of scope
(next): gate-level synthesis flow and bitstream attestation (Stage C).

### Stage C — attestation into the audit chain (engineering)
The audit chain already pins checker-source hashes and per-certificate kernel
verdicts; extend the schema with bitstream hashes and device identity so a chain
entry attests *which proven hardware* checked each shot. No architectural change.

### Stage D — checker on the syndrome bus (system)
Per-shot verdict bits at line rate beside the decoder; sampled shots re-verified
offline by the actual Lean kernel (defense in depth: fast hardware check on every
shot, slow kernel check on an audited sample). Decoder vendors keep their
internals closed; their outputs become accountable anyway.

## Production-mode honesty

Per-shot **failure** witnesses require a reference error, so runtime certification
is: syndrome-consistency (+ decoder-claimed logical-class witnesses, which a
decoder can emit as a cheap byproduct of its own linear algebra) on every shot,
with **full two-sided certification on injected-error audit shots** interleaved
into idle windows — the RAM-scrubbing pattern. Both modes are already expressible
against the Lean layer here; Stage A makes the split explicit in the API.

## Nearer-term hardening (independent of the hardware path)

- Wrap a production decoder (BP+LSD / Relay-BP) behind the same certificate layer.
- Phenomenological noise (measurement errors, multi-round windows), then
  circuit-level detector error models — the witness algebra remains F₂-linear.
- [[288,12,18]] and larger certificates; Stim-based sampling harness.

Contributions welcome at every stage; the theorems in `proofs/` are the contract.
