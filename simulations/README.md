<!-- Copyright (c) 2026 Justin Arndt. All rights reserved. GNU GPLv3; see LICENSE. -->
# simulations/ — cryogenic emulation pipeline (zero proprietary parameters)

A 100% open-source path from the **Lean-emitted Verilog** (`../hardware/`) down to
superconducting-logic timing, anchored to the IARPA SuperTools / ColdFlux
ecosystem. No foundry NDA, no dilution refrigerator, no vendor cell library is
required to reproduce any of this.

## Layers and their honest status

| Layer | File | Runs in-sandbox? | External tools |
|---|---|---|---|
| **Streaming behavioural demo** | `stream_demo.py` | ✅ **yes, now** | none (pure Python) |
| HDL co-sim testbench | `test_qldpc_checker.py` | needs a simulator | cocotb + iverilog/verilator |
| SFQ structural synthesis | `synth_sfq.ys` | needs Yosys + RSFQlib | yosys, `fetch_libs.sh` |
| Josephson-junction transient | `tb_josim.sp` | needs JoSIM + models | josim-cli, `fetch_libs.sh` |

`stream_demo.py` is the layer that runs here and now — it exercises the exact
Lean-emitted netlist (`../hardware/*_netlist.json`) gate-for-gate on a large
matrix of live decode runs plus adversarial corruptions, and reports throughput
and verdict-match. The other three layers are **faithful, un-fabricated
scaffolding**: they reference the *real* open-source libraries (fetched by
`fetch_libs.sh`), and are documented as requiring their respective external
tools. Nothing here ships a mocked-up vendor cell library.

## What each layer proves

- **`stream_demo.py`** — the checker's logical behaviour at scale: every one of N
  streamed runs gets the mathematically expected two-sided verdict, and every
  corrupted run is rejected. This is the software-level analogue of "line rate,"
  independent of any HDL simulator.
- **`test_qldpc_checker.py`** — the same behaviour through a real HDL simulator,
  driving the actual combinational ports of `../hardware/*_checker.v`
  (`obs, c1, c2, i1, i2, wv, z1, z2 → syn_ok_corr, syn_ok_inj, success_ok,
  fail_ok`). The embedded test vectors are genuine outputs of the decode +
  witness-extraction pipeline (not placeholders).
- **`synth_sfq.ys`** — maps the CMOS-agnostic gate netlist onto **RSFQ**
  superconducting primitives using the open SunMagnetics/ColdFlux
  [`RSFQlib`](https://github.com/sunmagnetics/RSFQlib) (itself GPLv3).
- **`tb_josim.sp`** — a JoSIM ([JoeyDelp/JoSIM](https://github.com/JoeyDelp/JoSIM))
  transient template using the RCSJ Josephson-junction model, for picosecond
  pulse-level timing of a checker primitive.

## Quick start

```bash
# runs immediately, no external tools:
python3 stream_demo.py --code gross144 --runs 5000

# full SFQ toolchain (after installing yosys, JoSIM, cocotb + iverilog):
bash fetch_libs.sh                      # clones the REAL RSFQlib + JoSIM upstreams
yosys -s synth_sfq.ys                   # CMOS-agnostic gates -> RSFQ primitives
josim-cli tb_josim.sp                   # Josephson-junction transient timing
SIM=icarus TOPLEVEL=code72_checker python3 -m cocotb ...   # HDL co-sim
```

## Honesty note

Only `stream_demo.py` has been executed in this repository's CI/sandbox. The
Yosys/JoSIM/cocotb layers are correct, runnable scaffolding but depend on
external tools not present here; treat their outputs as reproducible-by-you, not
as results this repo has already measured. Gate counts and depths quoted
elsewhere come from `../hardware/gate_report.json` (produced by
`../impl/rtl_equiv.py`), not from a synthesis run.
