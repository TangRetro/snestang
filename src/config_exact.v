// Selects the exact-lock video path (src/snes2hdmi_sd.v, plla/pll_snes_exact.v or
// pllr/pll_hdmi_nano_exact.v, hdmi2 mode 203/204). Added FIRST by build.tcl for the
// *_exact targets so the macro is defined before any other file is analysed; the stock
// targets never add it and are the upstream build.
`define EXACT_LOCK 1
