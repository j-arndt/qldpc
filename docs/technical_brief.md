<!-- Copyright (c) 2026 Justin Arndt. All rights reserved. GNU GPLv3; see LICENSE. -->
# Technical brief — a zero-trust co-processor for fault-tolerant QLDPC

**What this is.** A **1–2k-gate** (measured), Lean 4-verified hardware macro that
sits between an untrusted decoder and the physical qubit-control path and
certifies *every* decode outcome — two-sided (success **and** failure) — before a
single control pulse fires. The decoder stays a black box; the checker is the
trusted element, and its soundness is machine-checked, not asserted.

**What is measured vs. targeted (read this first).** Everything in the "measured"
column below is reproducible from this repo today. Everything in "target" is an
engineering projection for a partner's cells and has **not** been measured here.

| Quantity | Status | Value |
|---|---|---|
| Two-input gate count (full 4-output checker) | **measured** (`hardware/gate_report.json`) | 1,038 ([[72,12,6]]) · 2,082 ([[144,12,12]]) |
| Combinational depth | **measured** | ≈10 ([[72]]) · ≈11 ([[144]]) gate levels |
| Certificate soundness | **proven** (Lean 4, `proofs/`) | two-sided + exclusivity, standard axioms only |
| Software certificate cost | **measured** | ≈0.26–0.4 s / run (packed batch) |
| Power at 10 mK | *target* | not characterized — small gate count suggests low draw, but no power analysis has been run |
| Clock regime | *target* | RSFQ operates at tens of GHz; our netlist is combinational and un-timed until mapped to a cell library (see `simulations/`) |

The checker's mathematics is specialized to **bivariate bicycle (BB) codes** —
$[[72,12,6]]$, $[[90,8,10]]$, $[[108,8,10]]$, $[[144,12,12]]$ (the IBM "gross"
code), and $[[288,12,18]]$ — so its parity-check structure matches these code
families gate-for-gate.

---

## 1. SEEQC — cryogenic on-chip firewall

**Bottleneck.** SEEQC's Digital Quantum Management runs SFQ logic beside the
qubits at ~10 mK, where the thermal budget is brutal: heavy decoding (BP-OSD,
clustering) must run at room temperature on GPUs and stream corrections back
down. Those corrections arrive **unchecked** at the coldest, most fragile point
in the system.

**Value.** The checker is a small enough gate macro to be a candidate for
mapping onto an SFQ control layer inside the fridge (subject to SEEQC's own cell
library and thermal analysis — see the 90-day SOW). It validates the streamed
correction against the syndrome *before* the control pulses fire; a
communication glitch or decoder edge-case trips a **failure witness** instead of
corrupting the logical state. We claim the small gate count (measured); we do
**not** claim a power figure — characterizing draw on SEEQC's cells is Milestone 2
work.

## 2. Riverlane — hardening the "Era of Logic" decode path

**Bottleneck.** As logical clock rates climb, an unmapped edge-case or software
regression in a heuristic decoder becomes **silent data corruption** — it
falsifies benchmarks and spoils live computations with no alarm.

**Value.** We enforce the **certifying-algorithms paradigm**: the decoder is not
verified (a multi-year formal-methods effort), it is *checked*. The checker
demands an unforgeable two-sided certificate ($H_X^{\top}w = r$ for success, or a
$z$ with $H_X z = 0 \wedge \langle z,r\rangle = 1$ for failure). If the decoder is
wrong, the hardware proves it and flags it — turning silent corruption into a
loud, certificated fault. Soundness and the impossibility of a run carrying both
certificates are Lean theorems in this repo.

## 3. IBM Quantum — BB-code syndrome validation

**Bottleneck.** IBM's QLDPC roadmap leans on BB codes with congested,
long-range, tightly-timed classical syndrome buses.

**Value.** The Lean proofs are written directly over BB code spaces (including
$[[144,12,12]]$ and $[[288,12,18]]$), so the emitted macro matches the parity
checks gate-for-gate. It is combinational (depth ≈10–11 gate levels, measured),
so on a control FPGA/ASIC it can validate within a tight timing window; the exact
cycle budget depends on the target clock and cell library and is a Milestone 2
deliverable, not a figure claimed here.

---

## Trust boundary (stated plainly for evaluators)

- **Verified:** the checker's soundness theorems and the equality of the emitted
  gate netlist to the certified validator (Lean 4, zero `sorry`, standard axioms
  only; `lake build proofs.AxiomAudit`).
- **Trusted (small, stated, completely tested):** the ~100-line Verilog/JSON
  printer (`proofs/Netlist.lean`), independently cross-checked by **complete
  (non-sampled) matrix equality** in `impl/rtl_equiv.py` — every output bit of
  every linear layer compared entry-by-entry against an independently constructed
  dense ground truth. A linear map is determined by its matrix, so this test
  catches any logical-behaviour-altering printer bug deterministically, matching
  standard ASIC combinational equivalence-checking practice. A future hardening
  step (see `ROADMAP.md` Stage B+) removes the printer from the trusted base
  entirely via verified translation validation.
- **Not verified — by design:** the decoder itself; and the physical-layer
  mapping (cell library, timing, power), which is exactly what a partner
  engagement characterizes.
- **Out of scope:** binding recorded runs to physical device I/O (attested I/O),
  and circuit-level noise. Accuracy figures elsewhere are code-capacity iid-X.

---

## Commercial roadmap — 90-day integration proposal

Available for a fixed-fee, 90-day integration contract. Because the whole
synthesis/validation stack runs on open-source tooling (Yosys, JoSIM, cocotb,
the GPLv3 RSFQlib), **no exchange of proprietary vendor IP or foundry data is
required to begin.**

**Milestone 1 — Matrix ingestion & port mapping (Days 1–30).** Map the client's
QLDPC variants / parity matrices into the Lean environment; produce verified
two-sided-witness soundness proofs for their code spaces; define the syndrome-bus
pin interface (parallel/serialized). *Deliverable:* client-specific proofs +
emitted netlist + interface spec.

**Milestone 2 — Target-cell synthesis & timing (Days 31–60).** Retarget the RTL
from the open RSFQlib to the client's cells (CMOS, FPGA LUTs, or proprietary
SFQ/ERSFQ); run Yosys/DC mapping and JoSIM/SPICE transient timing to establish
the real validation-loop latency and (for the first time) a power estimate on
their process. *Deliverable:* mapping scripts + timing/power report.

**Milestone 3 — Testbench, audit chaining & handoff (Days 61–90).** Integrate the
HMAC-chained audit logging, deliver a cocotb/SystemVerilog suite with 100%
failure-witness-injection coverage, and hand off a pre-validated macro package
ready for tapeout or bitstream. *Deliverable:* full test suite + macro package.

**Engagement.** A paid exclusive evaluation option and a netlist walkthrough are
available on request. Contracts process via standard single-member LLC / sole-
proprietor vendor onboarding. Contact: **Justin Arndt — justinarndt05@gmail.com**.
