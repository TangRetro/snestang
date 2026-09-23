// SNES exact-lock HDMI clocks for Tang Nano 20K (GW2AR-18C), 2026-09-23.
// Derived from the author's smstang src/pllr/pll_nano_exact.v. GPL-3.0-or-later.
//
// The core clocks stay upstream's (src/pllr/gowin_pll_snes.v: 27 x 16/5 = 86.4 MHz fclk,
// CLKOUTD /4 = 21.6 MHz mclk, +0.57% vs NTSC). Only the HDMI clock changes:
//   rPLL: 27 x 5 = 135.000 MHz TMDS bit clock (IDIV 0, FBDIV 4, ODIV 4 -> VCO 540)
//   CLKDIV /5    =  27.000 MHz pixel clock, edge-aligned to the TMDS clock
// pixel / mclk = 27 / 21.6 = 1.25 EXACTLY (both PLLs lock to the same crystal), so a
// 1360-mclk source line is 1700 pixel clocks = 2 lines of hdmi mode 204 (850 x 524).

module pll_hdmi_nano_exact (
    input  clkin,           // 27 MHz crystal
    output clk_pixel,       // 27 MHz
    output clk_5x,          // 135 MHz
    output lock
);

wire gw_vcc = 1'b1;
wire gw_gnd = 1'b0;

rPLL pll_hdmi (
    .CLKOUT(clk_5x), .LOCK(lock), .CLKOUTP(), .CLKOUTD(), .CLKOUTD3(),
    .RESET(gw_gnd), .RESET_P(gw_gnd), .CLKIN(clkin), .CLKFB(gw_gnd),
    .FBDSEL({6{gw_gnd}}), .IDSEL({6{gw_gnd}}), .ODSEL({6{gw_gnd}}),
    .PSDA({4{gw_gnd}}), .DUTYDA({4{gw_gnd}}), .FDLY({4{gw_vcc}})
);
defparam pll_hdmi.FCLKIN = "27";
defparam pll_hdmi.DYN_IDIV_SEL = "false";
defparam pll_hdmi.IDIV_SEL = 0;
defparam pll_hdmi.DYN_FBDIV_SEL = "false";
defparam pll_hdmi.FBDIV_SEL = 4;
defparam pll_hdmi.DYN_ODIV_SEL = "false";
defparam pll_hdmi.ODIV_SEL = 4;
defparam pll_hdmi.PSDA_SEL = "0000";
defparam pll_hdmi.DYN_DA_EN = "false";
defparam pll_hdmi.DUTYDA_SEL = "1000";
defparam pll_hdmi.CLKOUT_FT_DIR = 1'b1;
defparam pll_hdmi.CLKOUTP_FT_DIR = 1'b1;
defparam pll_hdmi.CLKOUT_DLY_STEP = 0;
defparam pll_hdmi.CLKOUTP_DLY_STEP = 0;
defparam pll_hdmi.CLKFB_SEL = "internal";
defparam pll_hdmi.CLKOUT_BYPASS = "false";
defparam pll_hdmi.CLKOUTP_BYPASS = "false";
defparam pll_hdmi.CLKOUTD_BYPASS = "false";
defparam pll_hdmi.DYN_SDIV_SEL = 2;
defparam pll_hdmi.CLKOUTD_SRC = "CLKOUT";
defparam pll_hdmi.CLKOUTD3_SRC = "CLKOUT";
defparam pll_hdmi.DEVICE = "GW2AR-18C";

// Pixel clock by dividing the TMDS clock, not from a PLL output: the serializer needs
// its two clocks edge-aligned, which a separate PLL output would not guarantee.
CLKDIV #(.DIV_MODE("5"), .GSREN("false")) div5 (
    .CLKOUT(clk_pixel), .HCLKIN(clk_5x), .RESETN(lock), .CALIB(gw_gnd)
);

endmodule
