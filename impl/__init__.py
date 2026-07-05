# Copyright (c) 2026 Justin Arndt. All rights reserved.
# Licensed under the GNU GPLv3. For commercial licensing and proprietary
# hardware mapping, see the LICENSE file (dual-licensing notice at top).
"""qldpc-cert: kernel-checked certification of QLDPC decoder outputs.

Quick start (code-capacity, single run):
    from qldpc_cert import get_code, certify_run
    result = certify_run("gross144", p=0.02, seed=42)
    print(result["outcome"], result["kernel_check_ok"])

Quick start (phenomenological noise):
    from qldpc_cert import certify_spacetime_run, get_code
    result = certify_spacetime_run(get_code("code72"), d=3, p_data=0.01,
                                    p_meas=0.01, seed=42)
    print(result["outcome"])

Batch certification (~0.3 s/run marginal):
    from qldpc_cert import certify_batch
    result = certify_batch("gross144", p=0.06, n_runs=24, seed=1)
    print(result["kernel_check_ok"], result["per_run_marginal_estimate_s"])
"""

from codes import BBCode, get_code, REGISTRY
from certgen import certify_one_run as certify_run, certify_batch
from phenomenological import (
    build_H_st,
    certify_spacetime_run,
    run_phenom_campaign,
)

__version__ = "0.1.0"
__all__ = [
    "BBCode", "get_code", "REGISTRY",
    "certify_run", "certify_batch",
    "build_H_st", "certify_spacetime_run", "run_phenom_campaign",
]
