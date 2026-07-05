# Copyright (c) 2026 Justin Arndt. All rights reserved.
# Licensed under the GNU GPLv3. See the LICENSE file (dual-licensing notice).
"""Regenerate genuine (obs, c1, c2, i1, i2, wv, z1, z2) test vectors for the
cocotb testbench, by running the real decode + GF(2) witness-extraction pipeline
and packing the results into the checker's bit-order (idx(i,j) = i*m + j).

Usage:  python3 gen_vectors.py            # prints one success + one failure vector
Nothing here is hand-authored: every integer is a packed output of impl/.
"""
from __future__ import annotations
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "impl"))
import numpy as np
import structured as st
import logical as lg
from codes import get_code
from decoder import decode_batch


def pack(bits) -> int:
    o = 0
    for i, b in enumerate(bits):
        if b:
            o |= 1 << i
    return o


def gen(code_name="code72", seed=2026):
    code = get_code(code_name); HX, HZ = code.HX(), code.HZ(); lm = code.l * code.m
    rng = np.random.default_rng(seed)
    out = {}
    for want, p in [("success", 0.02), ("failure", 0.06)]:
        for _ in range(8000):
            err = (rng.random((1, 2, code.l, code.m)) < p).astype(np.uint8)
            syn = st.np_syndromeZ(code, err[:, 0], err[:, 1])
            eh, _ = decode_batch(code, syn, p, HZ=HZ)
            ef = st.flatten_qubitvec(err[:, 0], err[:, 1])
            r = (eh[0] ^ ef[0]).astype(np.uint8)
            oc, w = lg.logical_witness(HX, r)
            if oc == want:
                wv, z1, z2 = ((pack(w), 0, 0) if want == "success"
                              else (0, pack(w[:lm]), pack(w[lm:])))
                out[want] = dict(obs=pack(st.flatten_lm(syn[0])),
                                 c1=pack(eh[0][:lm]), c2=pack(eh[0][lm:]),
                                 i1=pack(ef[0][:lm]), i2=pack(ef[0][lm:]),
                                 wv=wv, z1=z1, z2=z2, weight=int(ef[0].sum()))
                break
    return out


if __name__ == "__main__":
    print(json.dumps(gen(), indent=2))
