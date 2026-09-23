// Exact-lock timing constraints (2026-09-23), derived from upstream src/snestang.sdc:
// same clocks and the same SDRAM multicycle rules, new periods.
// Console 60K / Primer 25K: fclk 85.9375 (VCO 859.375 / 10), mclk = fclk / 4 (ODIV 40),
// TMDS 134.277 (PLL 2), pixel = TMDS / 5 (CLKDIV) = 26.855.
//
// The video clocks are rationally related to mclk, but every crossing between the two
// groups is a designed CDC (dual-clock line buffer, toggle synchronisers, audio FIFO,
// iosys overlay), so the groups are asynchronous for analysis.

// set_multicycle_path: https://docs.xilinx.com/r/en-US/ug903-vivado-using-constraints/set_multicycle_path-Syntax

create_clock -name sys_clk -period 20 -waveform {0 10} [get_ports {sys_clk}]
create_clock -name fclk -period 11.636 -waveform {0 5.818} [get_nets {fclk}]
create_generated_clock -name mclk -source [get_nets {fclk}] -divide_by 4 [get_nets {mclk}]

create_clock -name hclk5 -period 7.447 -waveform {0 3.724} [get_nets {hclk5}]
create_generated_clock -name hclk -source [get_nets {hclk5}] -master_clock hclk5 -divide_by 5 [get_nets {hclk}]

// see start of sdram_snes.v for detailed timing of sdram
// SNES to sdram, 3*fclk
set_multicycle_path 3 -setup -end -from [get_clocks {mclk}] -to [get_clocks {fclk}]
set_multicycle_path 2 -hold -end -from [get_clocks {mclk}] -to [get_clocks {fclk}]
// Except vram?_req for refresh
set_multicycle_path 1 -setup -end -from [get_nets {vram?_req}] -to [get_clocks {fclk}]

// sdram to SNES
set_multicycle_path 3 -setup -start -from [get_clocks {fclk}] -to [get_clocks {mclk}]
set_multicycle_path 2 -hold -start -from [get_clocks {fclk}] -to [get_clocks {mclk}]

// Last constraint takes precedence: PPU to sdram is even longer at 6 fclk cycles
//set_multicycle_path 6 -setup -end -from [get_nets {main/SNES/PPU/BG*}] -to [get_clocks {fclk}]
//set_multicycle_path 5 -hold -end -from [get_nets {main/SNES/PPU/BG*}] -to [get_clocks {fclk}]

// false paths
//set_false_path -from [get_regs {main/SNES/smp/CPUO*}] -to [get_regs {sdram/dq_out*}]


set_clock_groups -asynchronous -group [get_clocks {fclk mclk}] -group [get_clocks {hclk5 hclk}]
