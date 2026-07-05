# Copyright (c) 2026 Justin Arndt. All rights reserved.
# Licensed under the GNU GPLv3. See the LICENSE file (dual-licensing notice).
"""cocotb HDL co-simulation of the Lean-emitted checker (../hardware/code72_checker.v).

The checker is COMBINATIONAL: it has no clock or reset. It maps the syndrome bus,
the room-temperature decoder's correction, an injected/reference error, and a
witness onto four verdict bits. This testbench drives the real ports and checks
the verdicts. The two test vectors below are GENUINE outputs of the decode +
GF(2) witness-extraction pipeline (impl/), not placeholders.

Run (example, Icarus Verilog backend):
    pip install cocotb
    # with a cocotb makefile or runner pointing TOPLEVEL=code72_checker
    #   VERILOG_SOURCES=../hardware/code72_checker.v  SIM=icarus

Ports (each 36-bit for code72): obs, c1, c2, i1, i2, wv, z1, z2
Outputs: syn_ok_corr, syn_ok_inj, success_ok, fail_ok
"""

import cocotb
from cocotb.triggers import Timer

# real vectors (code72, 36-bit words) -- regenerate via simulations/gen_vectors.py
SUCCESS = dict(obs=2230288, c1=8388608, c2=4194304, i1=8388608, i2=4194304,
               wv=0, z1=0, z2=0)   # weight-2 error, clean recovery
FAILURE = dict(obs=13023624664, c1=2196224, c2=528, i1=17302018, i2=8657043520,
               wv=0, z1=1310750, z2=0)   # weight-7 error, certified logical failure


def _drive(dut, v):
    dut.obs.value = v["obs"]; dut.c1.value = v["c1"]; dut.c2.value = v["c2"]
    dut.i1.value = v["i1"];  dut.i2.value = v["i2"]
    dut.wv.value = v["wv"];  dut.z1.value = v["z1"]; dut.z2.value = v["z2"]


@cocotb.test()
async def test_success_certificate(dut):
    """A legitimate correction must certify: success_ok=1, fail_ok=0."""
    _drive(dut, SUCCESS)
    await Timer(1, units="ns")   # settle combinational logic
    assert int(dut.syn_ok_corr.value) == 1, "correction did not reproduce the syndrome"
    assert int(dut.syn_ok_inj.value) == 1
    assert int(dut.success_ok.value) == 1, "firewall failed to certify a valid correction"
    assert int(dut.fail_ok.value) == 0


@cocotb.test()
async def test_failure_certificate(dut):
    """A certified logical failure must assert fail_ok and NOT success_ok."""
    _drive(dut, FAILURE)
    await Timer(1, units="ns")
    assert int(dut.syn_ok_corr.value) == 1
    assert int(dut.success_ok.value) == 0, "firewall passed a logically-failed correction!"
    assert int(dut.fail_ok.value) == 1, "failure witness not asserted"


@cocotb.test()
async def test_corrupted_correction_is_rejected(dut):
    """Garbage from an untrusted room-temp decoder must break syndrome consistency."""
    _drive(dut, SUCCESS)
    dut.c1.value = SUCCESS["c1"] ^ 0x1   # flip one bit of the correction
    await Timer(1, units="ns")
    assert int(dut.syn_ok_corr.value) == 0, "firewall accepted a corrupted correction!"
