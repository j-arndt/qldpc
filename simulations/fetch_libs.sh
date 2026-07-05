#!/usr/bin/env bash
# Copyright (c) 2026 Justin Arndt. GNU GPLv3; see LICENSE.
# Fetch the REAL open-source superconducting-EDA libraries this pipeline targets.
# Nothing here is vendored or fabricated -- these clone genuine upstream repos.
set -euo pipefail
cd "$(dirname "$0")"

# SunMagnetics / ColdFlux RSFQ cell library (GPLv3) -- IARPA SuperTools lineage.
# Provides behavioural Verilog cell models + JoSIM RCSJ device models.
if [ ! -d RSFQlib ]; then
  git clone --depth 1 https://github.com/sunmagnetics/RSFQlib RSFQlib
fi
echo "RSFQlib cells:   $(ls RSFQlib 2>/dev/null | head -1) ... (see RSFQlib/README)"

# JoSIM -- Josephson-junction SPICE transient simulator (build separately per its README).
if [ ! -d JoSIM ]; then
  git clone --depth 1 https://github.com/JoeyDelp/JoSIM JoSIM
fi
echo "JoSIM source:    JoSIM/  (build with cmake per JoSIM/README.md, or 'pip install pyjosim')"

cat <<NOTE

Fetched the genuine upstreams. Next:
  * point synth_sfq.ys at RSFQlib's Verilog cell models + .lib (paths differ by
    RSFQlib version; see RSFQlib/README and the 'Old Versions' tree).
  * point tb_josim.sp '.include' at RSFQlib's JoSIM model file.
  * install Yosys (https://github.com/YosysHQ/yosys) for structural synthesis.
These tools are NOT bundled with this repo; this project ships only the
CMOS-agnostic gate netlist (../hardware/) and the mapping/testbench scripts.
NOTE
