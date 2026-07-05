#!/usr/bin/env bash
# Forgery-rejection demonstration: asserts the verified checker REJECTS three
# forged certificates and ACCEPTS one soundness probe (unbounded but semantically
# harmless witness bits). Run from the repo root:  bash certs/attacks/run_attacks.sh
# Exit 0 iff every attack has its expected outcome.
set -u
export PATH="$HOME/.elan/bin:$PATH"
declare -A EXPECT=(
  [attack1_garbage_highbit]=REJECT
  [attack2_forged_success]=REJECT
  [attack3_corrupt_syndrome]=REJECT
  [attack4_garbage_witness_sound]=ACCEPT
)
fail=0
for name in "${!EXPECT[@]}"; do
  if lake env lean "certs/attacks/$name.lean" >/dev/null 2>&1; then got=ACCEPT; else got=REJECT; fi
  want="${EXPECT[$name]}"
  if [[ "$got" == "$want" ]]; then echo "OK   $name: $got (expected $want)";
  else echo "FAIL $name: $got (expected $want)"; fail=1; fi
done
if [[ $fail -eq 0 ]]; then echo "ALL ATTACKS BEHAVED AS EXPECTED"; else echo "ATTACK CHECK FAILED"; fi
exit $fail
