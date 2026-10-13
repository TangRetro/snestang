#!/bin/sh
# DSPn ROM-load equivalence test (Verilator). Needs git history: the old DSPn and the
# built-in ROM images come from the commit before the change and stay in obj/.
# Usage: sim/dsprom/run.sh [mutant]   (mutant: byteswap | nostart)
set -e
cd "$(dirname "$0")"
H=src/chip/DSP/dsp11b23410_p.hex
if git cat-file -e HEAD:$H 2>/dev/null; then OLD=HEAD     # change not committed yet
else OLD=$(git rev-list -n1 HEAD -- ../../$H)^; fi           # parent of the commit that removed it
rm -rf obj && mkdir obj
git show $OLD:src/chip/DSP/DSPn.v | sed 's/^module DSPn(/module DSPn_old(/' > obj/DSPn_old.v
git show $OLD:src/chip/DSP/dsp11b23410_p.hex > obj/dsp11b23410_p.hex
git show $OLD:src/chip/DSP/dsp11b23410_d.hex > obj/dsp11b23410_d.hex
cp ../../src/chip/DSP/DSPn.v obj/DSPn.v
case "$1" in
  byteswap) sed -i 's/prog_wd <= {LOAD_DI, ld_acc};/prog_wd <= {ld_acc[7:0], ld_acc[15:8], LOAD_DI};/' obj/DSPn.v ;;
  nostart)  sed -i 's/if (LOAD_START) begin/if (1'"'"'b0) begin/' obj/DSPn.v ;;
esac
verilator --binary -Wno-fatal -Wno-lint -Wno-style --top-module tb -Mdir obj/v \
    tb.sv obj/DSPn.v obj/DSPn_old.v dsp_data_ram_sim.v >obj/build.log 2>&1 \
    || { tail -20 obj/build.log; exit 1; }
cd obj
for v in 0 1 2 3; do ./v/Vtb +ver=$v +verilator+rand+reset+0 2>/dev/null | grep -E 'VER|MISMATCH' | tail -3; done
