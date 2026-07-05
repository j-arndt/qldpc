* Copyright (c) 2026 Justin Arndt. GNU GPLv3; see LICENSE.
* JoSIM transient template: time a single checker XOR primitive (the syndrome
* parity element) as an RSFQ cell, using the RCSJ Josephson-junction model.
* Run:  josim-cli tb_josim.sp     (after ./fetch_libs.sh; adjust .include path)
*
* STATUS: template. It references the RSFQ JoSIM model file from the fetched
* RSFQlib (path is version-dependent). This repo does NOT bundle those device
* models, and has NOT executed this simulation -- it is provided so a partner
* can reproduce picosecond-level timing on their own JoSIM install.

.include RSFQlib/josim/RSFQ_models.inc      $ from ./fetch_libs.sh (adjust path)

* RCSJ junction params are illustrative 10 mK SFQ values; the authoritative
* numbers live in RSFQlib's model file above. Do not quote these as measured.
.model jj_rsfq jj(rtype=1, cap=1.2p, icrit=0.1m, r0=2.5, rn=15.0, vg=2.8m)

* --- One RSFQ XOR2 cell driven by a syndrome-bit SFQ pulse -------------------
* Bias + input JTL + XOR cell come from the RSFQlib subcircuits; wire them here.
* Xin    in 0            pulse_source
* Xxor   in bias out 0   RSFQ_XOR      $ RSFQlib subckt
.tran 0.25p 200p
.print phase v(out)
.end
