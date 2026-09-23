// Modifications copyright (c) 2026 Romain Tisserand.
// Derived from this repository's own src/snes2hdmi.v (nand2mario) and the author's smstang
// src/sms2hdmi_sd.sv; only the changes are covered above. GPL-3.0-or-later.
//
// EXACT-LOCK SNES -> HDMI, line-buffered (2026-09-23).
//
// src/snes2hdmi.v runs its pixel clock (74.25 MHz, 720p) off a PLL unrelated to the SNES
// master clock. The two rasters drift, so it keeps a 16/32-line buffer AND stops the
// emulated SNES once per frame (pause_snes_for_frame_sync) until HDMI catches up -- the
// source of its per-frame stall and of the faster-than-real APU (dsp.vh ACLK_FREQ) that
// papers over the lost audio.
//
// Here clk_pixel / mclk = 1.25 EXACTLY on every board (see plla/pll_snes_exact.v and
// pllr/pll_hdmi_nano_exact.v), so:
//
//     one source line  = 1360 mclk = 1700 pixel clocks = 2 output lines of 850
//     one source frame = 262 source lines = 524 output lines   (hdmi mode 203/204)
//
// Every source line is exactly two output lines, for ever: three line buffers, no pause.
//
// DEPENDENCY -- READ BEFORE TOUCHING ppu.v: the 1360-mclk line exists only because of
// ppu.v's `H_CNT == 323 && H_CNT == 327` (always false), which never inserts the two
// 6-mclk long dots. A real SNES line is 1364 mclk, and on odd non-interlaced frames line
// 240 is 1360. Fixing that condition makes the frame length vary frame to frame, which
// this fixed 850 x 524 raster cannot follow: it would need its own compensation.
//
// NOT HANDLED (documented, not fixed):
//  - Interlace (BGINTERLACE): fields alternate 263/262 lines, 1 source line of drift per
//    2 fields. The phase checker below re-slams the raster when it sees the drift, so the
//    picture recovers, but a sink may resync each time. Only a handful of games use it.
//  - PAL: 312 lines, different clocks. Out of scope (NTSC build).
//
// Output is the CEA 720x480 active area declared VIC 2 (4:3). 224 source lines x2 = 448
// output lines, centred; 256 source pixels scaled to 672, which is 4:3 for 448 lines.

module snes2hdmi_sd #(
    parameter VIDEOID = 203,            // 203 = 26.855 MHz (C60/P25K), 204 = 27.000 (Nano)
    parameter CLKFRQ  = 26855           // clk_pixel in kHz (documentation; CTS is measured)
)(
	input clk,                          // snes mclk
	input resetn,

    // snes video and audio signals
    input dotclk,
    input hblank,
    input vblank,
    input [14:0] rgb5,
    input [8:0] xs,                     // {x,dotclk}
    input [8:0] ys,                     // {field,y}

    input overlay,
    output [7:0] overlay_x,
    output [7:0] overlay_y,
    input [14:0] overlay_color,

    input [15:0] audio_l,
    input [15:0] audio_r,
    input audio_ready,
    output audio_en,

	// video clocks -- clk_pixel MUST be mclk x 1.25 off the same reference
	input clk_pixel,
	input clk_5x_pixel,

	// output signals
	output       tmds_clk_n,
	output       tmds_clk_p,
	output [2:0] tmds_d_n,
	output [2:0] tmds_d_p
);

localparam AUDIO_BIT_WIDTH = 16;
localparam AUDIO_OUT_RATE  = 32000;     // nominal; the real rate is the APU's, see below

localparam SRC_W   = 256;
localparam SRC_H   = 224;
localparam DST_W   = 672;               // 256 -> 672: 4:3 for a 448-line picture
localparam XSTART  = (720 - DST_W) / 2; // 24
localparam YSTART  = (480 - SRC_H*2) / 2; // 16

wire [9:0]  cy;
wire [10:0] cx;

assign audio_en = 1'b1;

// ---------------------------------------------------------------------------------------
// Three line buffers, 256 x 15 bits each (4 slots of address space: one 18 Kb block).
// THREE, not two: a source line is written during the output pair BEFORE the one that
// shows it, and the third buffer gives a full line of slack either side.
// ---------------------------------------------------------------------------------------
reg [14:0] linebuf [0:4*SRC_W-1];
reg [1:0]  wr_sel = 2'd0;
reg [7:0]  ys_r = 8'd0;
reg        r_dotclk;
reg        wr_en;
reg [9:0]  wr_addr;
reg [14:0] wr_data;
reg        frame_start_x = 1'b0;        // toggles once per source frame (ys -> 0)

always @(posedge clk) begin
    r_dotclk <= dotclk;
    ys_r     <= ys[7:0];
    wr_en    <= 1'b0;
    // Slot = source line mod 3, restarted at line 0 so both sides agree every frame
    // (262 is not a multiple of 3).
    if (ys[7:0] != ys_r) begin
        if (ys[7:0] == 8'd0) begin
            wr_sel        <= 2'd0;
            frame_start_x <= ~frame_start_x;
        end else
            wr_sel <= (wr_sel == 2'd2) ? 2'd0 : wr_sel + 2'd1;
    end
    if (dotclk && ~r_dotclk && ~hblank && ~vblank && ys[7:0] < SRC_H) begin
        wr_addr <= {wr_sel, xs[8:1]};
        wr_data <= rgb5;
        wr_en   <= 1'b1;
    end
    if (wr_en) linebuf[wr_addr] <= wr_data;
end

// ---------------------------------------------------------------------------------------
// Frame phase. Source line n is being written during the output pair that starts when ys
// becomes n. Showing it one pair later (cy = YSTART + 2n) needs cy = YSTART - 2 at the
// moment ys becomes 0; hdmi.sv's raster-only `vreset` loads cy with START_Y for that.
// Under the exact lock this only has to happen once. After that the frame-start event
// must keep arriving at the same raster position; if it does not (interlace, reset, a
// clock glitch) the raster is re-slammed.
// ---------------------------------------------------------------------------------------
localparam [9:0] START_Y = YSTART - 2;

reg  fs_meta = 1'b0, fs_sync = 1'b0, fs_sync_r = 1'b0;
reg  locked_once = 1'b0;
reg  vreset = 1'b0;
reg  [9:0] cy_ref;

always @(posedge clk_pixel) begin
    fs_meta   <= frame_start_x;
    fs_sync   <= fs_meta;
    fs_sync_r <= fs_sync;
    vreset    <= 1'b0;
    if (fs_sync != fs_sync_r) begin
        if (!locked_once) begin
            vreset      <= 1'b1;
            locked_once <= 1'b1;
            cy_ref      <= START_Y;
        end else if (cy > cy_ref + 10'd1 || cy + 10'd1 < cy_ref) begin
            vreset <= 1'b1;             // lost phase: re-slam (see NOT HANDLED above)
        end
    end
end

// ---------------------------------------------------------------------------------------
// Read side, pixel clock.
// ---------------------------------------------------------------------------------------
wire        v_in = (cy >= YSTART) && (cy < YSTART + SRC_H*2);
wire        h_in = (cx >= XSTART) && (cx < XSTART + DST_W);
wire [9:0]  src_line = (cy - YSTART) >> 1;

reg  [1:0]  rd_sel = 2'd0;
reg  [8:0]  src_x  = 9'd0;
reg  [10:0] xacc   = 11'd0;
reg         active = 1'b0;
reg  [14:0] px;
reg  [23:0] rgb;

always @(posedge clk_pixel) begin
    if (cx == 0) begin
        if (cy == YSTART)                rd_sel <= 2'd0;
        else if (v_in && cy[0] == 1'b0)  rd_sel <= (rd_sel == 2'd2) ? 2'd0 : rd_sel + 2'd1;
    end
end

always @(posedge clk_pixel) begin
    active <= v_in && h_in;
    if (cx == 0) begin
        src_x <= 9'd0;
        xacc  <= 11'd0;
    end else if (v_in && h_in) begin
        xacc <= xacc + SRC_W[10:0];
        if (xacc + SRC_W[10:0] >= DST_W[10:0]) begin
            xacc  <= xacc + SRC_W[10:0] - DST_W[10:0];
            src_x <= src_x + 9'd1;
        end
    end

    px <= linebuf[{rd_sel, src_x[7:0]}];

    if (active) begin
        if (overlay)
            rgb <= {overlay_color[4:0],3'b0,overlay_color[9:5],3'b0,overlay_color[14:10],3'b0};
        else
            rgb <= {px[4:0],3'b0, px[9:5],3'b0, px[14:10],3'b0};     // BGR5 -> RGB8
    end else
        rgb <= 24'h000000;
end

assign overlay_x = src_x[7:0];
assign overlay_y = src_line[7:0];

// ---------------------------------------------------------------------------------------
// Audio. With no pause, the APU runs at its real rate (dsp.vh ACLK_FREQ = 409600 under
// EXACT_LOCK): one sample per 2147730 / 3200 mclk. The output sample clock is generated
// in the pixel domain at EXACTLY that rate -- toggle rate 6400 / 2147730 per mclk, i.e.
// 5120 / 2147730 per pixel clock (pixel = 1.25 mclk) -- so the FIFO can never drift.
// Popping waits until the FIFO has filled past its almost-empty mark once.
// ---------------------------------------------------------------------------------------
reg  [15:0] audio_sample_word [1:0];
reg  [31:0] aud_acc = 32'd0;
reg         clk_audio = 1'b0;
reg         audio_rinc;
reg         aud_started = 1'b0;
wire        audio_empty, audio_almost_empty;
wire [31:0] audio_sample;

always @(posedge clk_pixel) begin
    audio_rinc <= 1'b0;
    if (!audio_almost_empty) aud_started <= 1'b1;
    if (aud_acc + 32'd5120 >= 32'd2147730) begin
        aud_acc   <= aud_acc + 32'd5120 - 32'd2147730;
        clk_audio <= ~clk_audio;
        if (!clk_audio && aud_started && !audio_empty) begin
            {audio_sample_word[0], audio_sample_word[1]} <= audio_sample;
            audio_rinc <= 1'b1;
        end
    end else
        aud_acc <= aud_acc + 32'd5120;
end

dual_clk_fifo #(.DATESIZE(32), .ADDRSIZE(4)) audio_fifo (
    .clk(clk), .wrst_n(1'b1),
    .winc(audio_ready), .wdata({audio_l, audio_r}), .wfull(),
    .rclk(clk_pixel), .rrst_n(1'b1),
    .rinc(audio_rinc), .rdata(audio_sample), .rempty(audio_empty),
    .almost_full(), .almost_empty(audio_almost_empty)
);

// ---------------------------------------------------------------------------------------
// HDMI output: mode 203/204, 850 x 524, 720x480 active, VIC 2.
// ---------------------------------------------------------------------------------------
logic [2:0] tmds;
logic       tmdsClk;

hdmi #( .VIDEO_ID_CODE(VIDEOID),
        .DVI_OUTPUT(0),
        .VIDEO_REFRESH_RATE(60.0),
        .IT_CONTENT(1),
        .AUDIO_RATE(AUDIO_OUT_RATE),
        .AUDIO_BIT_WIDTH(AUDIO_BIT_WIDTH),
        .START_X(0),
        .START_Y(START_Y) )
hdmi( .clk_pixel_x5(clk_5x_pixel),
      .clk_pixel(clk_pixel),
      .clk_audio(clk_audio),
      .rgb(rgb),
      .reset(1'b0),
      .vreset(vreset),
      .audio_sample_word(audio_sample_word),
      .tmds(tmds),
      .tmds_clock(tmdsClk),
      .cx(cx),
      .cy(cy),
      .frame_width(),
      .frame_height() );

ELVDS_OBUF tmds_bufds [3:0] (
    .I({clk_pixel, tmds}),
    .O({tmds_clk_p, tmds_d_p}),
    .OB({tmds_clk_n, tmds_d_n})
);

endmodule
