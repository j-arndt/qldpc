-- Copyright (c) 2026 Justin Arndt. All rights reserved.
-- Licensed under the GNU GPLv3. For commercial licensing and proprietary
-- hardware mapping, see the LICENSE file (dual-licensing notice at top).
/- Stage B emission driver: run from repo root with `lake env lean scripts/EmitRTL.lean`.
   Writes bit-blasted Verilog + JSON netlists for the named codes. -/
import proofs.Netlist

open QLDPC QLDPC.RTL

#eval show IO Unit from do
  IO.FS.createDirAll "rtl"
  IO.FS.writeFile "hardware/code72_checker.v" (emitVerilog code72 "code72_checker")
  IO.FS.writeFile "hardware/code72_netlist.json" (emitJSON code72 "code72")
  IO.FS.writeFile "hardware/gross144_checker.v" (emitVerilog grossCode "gross144_checker")
  IO.FS.writeFile "hardware/gross144_netlist.json" (emitJSON grossCode "gross144")
  IO.println "RTL emitted: hardware/{code72,gross144}_checker.v + _netlist.json"
