// SNES exact-lock clocks for Console 60K / Primer 25K (50 MHz crystal), 2026-09-23.
// Derived from this repo's src/plla/gowin_pll_snes.v (Gowin IP output) and the author's
// smstang src/plla/pll_exact.v. GPL-3.0-or-later.
//
// PLL 1, FVCO = 50 / IDIV 2 x MDIV 34.375 = 859.375 MHz (PLLA range 700-1400, PFD 25):
//   ODIV 40 -> 21.484375 MHz  mclk   (NTSC 21.477273; +0.033%, same as upstream's 21.4844)
//   ODIV 10 -> 85.9375   MHz  fclk   = 4 x mclk, the SDRAM clock (as upstream)
//   ODIV 10 -> 85.9375   MHz  fclk_p, 180 degrees (PE_COARSE 5 of 10 = upstream's 8 of 16)
//   ODIV 32 -> 26.85546875 MHz pixel reference = mclk x 1.25 EXACTLY
// PLL 2, fed by the pixel reference: FVCO = 26.855 x 40 = 1074.22 MHz, ODIV 8 -> 134.277 MHz
//   TMDS bit clock = pixel x 5. The x5 cannot come off PLL 1: 859.375 / 134.277 = 6.4.
//   A PLL locked to PLL 1's output keeps the ratio exact (only jitter is added).
// clk_pixel = CLKDIV /5 of the TMDS clock, so the serializer's two clocks are edge-aligned.
//
// snestang's line is 1360 mclk; 1360 x 1.25 = 1700 = 2 x 850 pixel clocks, so every source
// line is exactly two output lines of hdmi mode 203 (850 x 524) for ever.

module pll_snes_exact (
    input  clkin,           // 50 MHz
    output mclk,
    output fclk,
    output fclk_p,
    output clk_5x,          // TMDS bit clock, 134.277 MHz
    output clk_pixel,       // 26.855 MHz
    output lock
);

wire gw_gnd = 1'b0;
wire clk_pixref;
wire pll_core_lock, pll_tmds_lock;
assign lock = pll_core_lock & pll_tmds_lock;

PLLA pll_core (
    .LOCK(pll_core_lock),
    .CLKOUT0(mclk),
    .CLKOUT1(fclk),
    .CLKOUT2(fclk_p),
    .CLKOUT3(clk_pixref),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKOUT6(),
    .CLKFBOUT(),
    .MDRDO(),
    .CLKIN(clkin),
    .CLKFB(gw_gnd),
    .RESET(gw_gnd),
    .PLLPWD(gw_gnd),
    .RESET_I(gw_gnd),
    .RESET_O(gw_gnd),
    .PSSEL({gw_gnd,gw_gnd,gw_gnd}),
    .PSDIR(gw_gnd),
    .PSPULSE(gw_gnd),
    .SSCPOL(gw_gnd),
    .SSCON(gw_gnd),
    .SSCMDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .SSCMDSEL_FRAC({gw_gnd,gw_gnd,gw_gnd}),
    .MDCLK(gw_gnd),
    .MDOPC({gw_gnd,gw_gnd}),
    .MDAINC(gw_gnd),
    .MDWDI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd})
);

defparam pll_core.FCLKIN = "50";
defparam pll_core.IDIV_SEL = 2;
defparam pll_core.FBDIV_SEL = 1;
defparam pll_core.ODIV0_SEL = 40;
defparam pll_core.ODIV1_SEL = 10;
defparam pll_core.ODIV2_SEL = 10;
defparam pll_core.ODIV3_SEL = 32;
defparam pll_core.ODIV4_SEL = 8;
defparam pll_core.ODIV5_SEL = 8;
defparam pll_core.ODIV6_SEL = 8;
defparam pll_core.MDIV_SEL = 34;
defparam pll_core.MDIV_FRAC_SEL = 3;
defparam pll_core.ODIV0_FRAC_SEL = 0;
defparam pll_core.CLKOUT0_EN = "TRUE";
defparam pll_core.CLKOUT1_EN = "TRUE";
defparam pll_core.CLKOUT2_EN = "TRUE";
defparam pll_core.CLKOUT3_EN = "TRUE";
defparam pll_core.CLKOUT4_EN = "FALSE";
defparam pll_core.CLKOUT5_EN = "FALSE";
defparam pll_core.CLKOUT6_EN = "FALSE";
defparam pll_core.CLKFB_SEL = "INTERNAL";
defparam pll_core.CLKOUT0_DT_DIR = 1'b1;
defparam pll_core.CLKOUT1_DT_DIR = 1'b1;
defparam pll_core.CLKOUT2_DT_DIR = 1'b1;
defparam pll_core.CLKOUT3_DT_DIR = 1'b1;
defparam pll_core.CLKOUT0_DT_STEP = 0;
defparam pll_core.CLKOUT1_DT_STEP = 0;
defparam pll_core.CLKOUT2_DT_STEP = 0;
defparam pll_core.CLKOUT3_DT_STEP = 0;
defparam pll_core.CLK0_IN_SEL = 1'b0;
defparam pll_core.CLK0_OUT_SEL = 1'b0;
defparam pll_core.CLK1_IN_SEL = 1'b0;
defparam pll_core.CLK1_OUT_SEL = 1'b0;
defparam pll_core.CLK2_IN_SEL = 1'b0;
defparam pll_core.CLK2_OUT_SEL = 1'b0;
defparam pll_core.CLK3_IN_SEL = 1'b0;
defparam pll_core.CLK3_OUT_SEL = 1'b0;
defparam pll_core.CLK4_IN_SEL = 2'b00;
defparam pll_core.CLK4_OUT_SEL = 1'b0;
defparam pll_core.CLK5_IN_SEL = 1'b0;
defparam pll_core.CLK5_OUT_SEL = 1'b0;
defparam pll_core.CLK6_IN_SEL = 1'b0;
defparam pll_core.CLK6_OUT_SEL = 1'b0;
defparam pll_core.DYN_DPA_EN = "FALSE";
defparam pll_core.CLKOUT0_PE_COARSE = 0;
defparam pll_core.CLKOUT0_PE_FINE = 0;
defparam pll_core.CLKOUT1_PE_COARSE = 0;
defparam pll_core.CLKOUT1_PE_FINE = 0;
defparam pll_core.CLKOUT2_PE_COARSE = 5;
defparam pll_core.CLKOUT2_PE_FINE = 0;
defparam pll_core.CLKOUT3_PE_COARSE = 0;
defparam pll_core.CLKOUT3_PE_FINE = 0;
defparam pll_core.CLKOUT4_PE_COARSE = 0;
defparam pll_core.CLKOUT4_PE_FINE = 0;
defparam pll_core.CLKOUT5_PE_COARSE = 0;
defparam pll_core.CLKOUT5_PE_FINE = 0;
defparam pll_core.CLKOUT6_PE_COARSE = 0;
defparam pll_core.CLKOUT6_PE_FINE = 0;
defparam pll_core.DYN_PE0_SEL = "FALSE";
defparam pll_core.DYN_PE1_SEL = "FALSE";
defparam pll_core.DYN_PE2_SEL = "FALSE";
defparam pll_core.DYN_PE3_SEL = "FALSE";
defparam pll_core.DYN_PE4_SEL = "FALSE";
defparam pll_core.DYN_PE5_SEL = "FALSE";
defparam pll_core.DYN_PE6_SEL = "FALSE";
defparam pll_core.DE0_EN = "FALSE";
defparam pll_core.DE1_EN = "FALSE";
defparam pll_core.DE2_EN = "FALSE";
defparam pll_core.DE3_EN = "FALSE";
defparam pll_core.DE4_EN = "FALSE";
defparam pll_core.DE5_EN = "FALSE";
defparam pll_core.DE6_EN = "FALSE";
defparam pll_core.RESET_I_EN = "FALSE";
defparam pll_core.RESET_O_EN = "FALSE";
defparam pll_core.ICP_SEL = 6'bXXXXXX;
defparam pll_core.LPF_RES = 3'bXXX;
defparam pll_core.LPF_CAP = 2'b00;
defparam pll_core.SSC_EN = "FALSE";


PLLA pll_tmds (
    .LOCK(pll_tmds_lock),
    .CLKOUT0(clk_5x),
    .CLKOUT1(),
    .CLKOUT2(),
    .CLKOUT3(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKOUT6(),
    .CLKFBOUT(),
    .MDRDO(),
    .CLKIN(clk_pixref),
    .CLKFB(gw_gnd),
    .RESET(gw_gnd),
    .PLLPWD(gw_gnd),
    .RESET_I(gw_gnd),
    .RESET_O(gw_gnd),
    .PSSEL({gw_gnd,gw_gnd,gw_gnd}),
    .PSDIR(gw_gnd),
    .PSPULSE(gw_gnd),
    .SSCPOL(gw_gnd),
    .SSCON(gw_gnd),
    .SSCMDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .SSCMDSEL_FRAC({gw_gnd,gw_gnd,gw_gnd}),
    .MDCLK(gw_gnd),
    .MDOPC({gw_gnd,gw_gnd}),
    .MDAINC(gw_gnd),
    .MDWDI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd})
);

defparam pll_tmds.FCLKIN = "26.855";
defparam pll_tmds.IDIV_SEL = 1;
defparam pll_tmds.FBDIV_SEL = 1;
defparam pll_tmds.ODIV0_SEL = 8;
defparam pll_tmds.ODIV1_SEL = 8;
defparam pll_tmds.ODIV2_SEL = 8;
defparam pll_tmds.ODIV3_SEL = 8;
defparam pll_tmds.ODIV4_SEL = 8;
defparam pll_tmds.ODIV5_SEL = 8;
defparam pll_tmds.ODIV6_SEL = 8;
defparam pll_tmds.MDIV_SEL = 40;
defparam pll_tmds.MDIV_FRAC_SEL = 0;
defparam pll_tmds.ODIV0_FRAC_SEL = 0;
defparam pll_tmds.CLKOUT0_EN = "TRUE";
defparam pll_tmds.CLKOUT1_EN = "FALSE";
defparam pll_tmds.CLKOUT2_EN = "FALSE";
defparam pll_tmds.CLKOUT3_EN = "FALSE";
defparam pll_tmds.CLKOUT4_EN = "FALSE";
defparam pll_tmds.CLKOUT5_EN = "FALSE";
defparam pll_tmds.CLKOUT6_EN = "FALSE";
defparam pll_tmds.CLKFB_SEL = "INTERNAL";
defparam pll_tmds.CLKOUT0_DT_DIR = 1'b1;
defparam pll_tmds.CLKOUT1_DT_DIR = 1'b1;
defparam pll_tmds.CLKOUT2_DT_DIR = 1'b1;
defparam pll_tmds.CLKOUT3_DT_DIR = 1'b1;
defparam pll_tmds.CLKOUT0_DT_STEP = 0;
defparam pll_tmds.CLKOUT1_DT_STEP = 0;
defparam pll_tmds.CLKOUT2_DT_STEP = 0;
defparam pll_tmds.CLKOUT3_DT_STEP = 0;
defparam pll_tmds.CLK0_IN_SEL = 1'b0;
defparam pll_tmds.CLK0_OUT_SEL = 1'b0;
defparam pll_tmds.CLK1_IN_SEL = 1'b0;
defparam pll_tmds.CLK1_OUT_SEL = 1'b0;
defparam pll_tmds.CLK2_IN_SEL = 1'b0;
defparam pll_tmds.CLK2_OUT_SEL = 1'b0;
defparam pll_tmds.CLK3_IN_SEL = 1'b0;
defparam pll_tmds.CLK3_OUT_SEL = 1'b0;
defparam pll_tmds.CLK4_IN_SEL = 2'b00;
defparam pll_tmds.CLK4_OUT_SEL = 1'b0;
defparam pll_tmds.CLK5_IN_SEL = 1'b0;
defparam pll_tmds.CLK5_OUT_SEL = 1'b0;
defparam pll_tmds.CLK6_IN_SEL = 1'b0;
defparam pll_tmds.CLK6_OUT_SEL = 1'b0;
defparam pll_tmds.DYN_DPA_EN = "FALSE";
defparam pll_tmds.CLKOUT0_PE_COARSE = 0;
defparam pll_tmds.CLKOUT0_PE_FINE = 0;
defparam pll_tmds.CLKOUT1_PE_COARSE = 0;
defparam pll_tmds.CLKOUT1_PE_FINE = 0;
defparam pll_tmds.CLKOUT2_PE_COARSE = 0;
defparam pll_tmds.CLKOUT2_PE_FINE = 0;
defparam pll_tmds.CLKOUT3_PE_COARSE = 0;
defparam pll_tmds.CLKOUT3_PE_FINE = 0;
defparam pll_tmds.CLKOUT4_PE_COARSE = 0;
defparam pll_tmds.CLKOUT4_PE_FINE = 0;
defparam pll_tmds.CLKOUT5_PE_COARSE = 0;
defparam pll_tmds.CLKOUT5_PE_FINE = 0;
defparam pll_tmds.CLKOUT6_PE_COARSE = 0;
defparam pll_tmds.CLKOUT6_PE_FINE = 0;
defparam pll_tmds.DYN_PE0_SEL = "FALSE";
defparam pll_tmds.DYN_PE1_SEL = "FALSE";
defparam pll_tmds.DYN_PE2_SEL = "FALSE";
defparam pll_tmds.DYN_PE3_SEL = "FALSE";
defparam pll_tmds.DYN_PE4_SEL = "FALSE";
defparam pll_tmds.DYN_PE5_SEL = "FALSE";
defparam pll_tmds.DYN_PE6_SEL = "FALSE";
defparam pll_tmds.DE0_EN = "FALSE";
defparam pll_tmds.DE1_EN = "FALSE";
defparam pll_tmds.DE2_EN = "FALSE";
defparam pll_tmds.DE3_EN = "FALSE";
defparam pll_tmds.DE4_EN = "FALSE";
defparam pll_tmds.DE5_EN = "FALSE";
defparam pll_tmds.DE6_EN = "FALSE";
defparam pll_tmds.RESET_I_EN = "FALSE";
defparam pll_tmds.RESET_O_EN = "FALSE";
defparam pll_tmds.ICP_SEL = 6'bXXXXXX;
defparam pll_tmds.LPF_RES = 3'bXXX;
defparam pll_tmds.LPF_CAP = 2'b00;
defparam pll_tmds.SSC_EN = "FALSE";


CLKDIV #(.DIV_MODE("5")) div5 (
    .CLKOUT(clk_pixel), .HCLKIN(clk_5x), .RESETN(pll_tmds_lock), .CALIB(gw_gnd)
);

endmodule
