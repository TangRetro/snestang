// DSPn ROM-load test: the DSPn with ROMs loaded through LOAD_* must behave exactly like
// the old DSPn with the six chip ROMs built in. Both run side by side on the same random
// CPU traffic; every cycle the fetched instruction, data ROM word and DO must match.
// run.sh supplies the old core and its ROM images (from git history, not kept in the repo).
module tb;
reg clk = 0;
always #1 clk = ~clk;

reg [2:0] VER;
reg REV = 1;
integer POFF, DOFF;

reg [23:0] P [8096];
reg [15:0] D [7168];

reg ce = 0, rst_n = 0;
reg a0 = 0, cs_n = 1, rd_n = 1, wr_n = 1, dp_sel = 0;
reg [7:0] di = 0;
reg [11:0] dp_addr = 0;
reg ld_start = 0, ld_we = 0;
reg [7:0] ld_di = 0;
wire [7:0] do_old, do_new;

DSPn_old old (.CLK(clk), .CE(ce), .RST_N(rst_n), .ENABLE(1'b1), .A0(a0), .DI(di), .DO(do_old),
    .CS_N(cs_n), .RD_N(rd_n), .WR_N(wr_n), .DP_ADDR(dp_addr), .DP_SEL(dp_sel), .VER(VER), .REV(REV));
DSPn dut (.CLK(clk), .CE(ce), .RST_N(rst_n), .ENABLE(1'b1), .A0(a0), .DI(di), .DO(do_new),
    .CS_N(cs_n), .RD_N(rd_n), .WR_N(wr_n), .DP_ADDR(dp_addr), .DP_SEL(dp_sel), .VER(VER), .REV(REV),
    .LOAD_START(ld_start), .LOAD_WE(ld_we), .LOAD_DI(ld_di));

integer i, b, errors = 0, cyc = 0, cmds = 0, cmp = 0;
reg [23:0] w;

task send(input [7:0] x);
    begin
        @(posedge clk) begin ld_we <= 1; ld_di <= x; end
        @(posedge clk) ld_we <= 0;
        repeat ($urandom % 3) @(posedge clk);       // the loader's bytes come with gaps
    end
endtask

initial begin
    if (!$value$plusargs("ver=%d", VER)) VER = 0;
    case (VER)
        0: begin POFF = 'h4F2;  DOFF = 'h400;  end   // DSP1B
        1: begin POFF = 'h9E5;  DOFF = 'h800;  end   // DSP2
        2: begin POFF = 'h10B8; DOFF = 'hC00;  end   // DSP3
        default: begin POFF = 'h16BD; DOFF = 'h1000; end // DSP4
    endcase
    $readmemh("dsp11b23410_p.hex", P);
    $readmemh("dsp11b23410_d.hex", D);

    // fill the new core's ROM with garbage first, then restart and load the real file:
    // LOAD_START must restart the counters
    @(posedge clk) ld_start <= 1; @(posedge clk) ld_start <= 0;
    for (i = 0; i < 100; i = i + 1) send($urandom);
    @(posedge clk) ld_start <= 1; @(posedge clk) ld_start <= 0;
    for (i = 0; i < 2048; i = i + 1) begin
        w = (POFF + i < 8096) ? P[POFF + i] : 24'h0;
        for (b = 0; b < 3; b = b + 1) send(w[8*b +: 8]);
    end
    for (i = 0; i < 1024; i = i + 1) begin
        w = {8'h0, D[DOFF + i]};
        for (b = 0; b < 2; b = b + 1) send(w[8*b +: 8]);
    end
    for (i = 0; i < 64; i = i + 1) send($urandom);  // bytes past 8 KB are ignored

    repeat (4) @(posedge clk);
    rst_n <= 1;
end

// random CPU traffic once running
integer phase = 0, hold = 0, npc = 0;
reg seen [2048];
initial for (int k = 0; k < 2048; k++) seen[k] = 0;
always @(posedge clk) begin
    ce <= ($urandom % 3) == 0;
    if (rst_n) begin
        cyc <= cyc + 1;
        if (hold != 0) hold <= hold - 1;
        else begin
            case (phase)
            0: begin                        // start an access
                a0 <= ($urandom % 4) == 0;  // mostly DR, sometimes SR
                dp_sel <= ($urandom % 16) == 0;
                dp_addr <= $urandom;
                di <= ($urandom % 2) ? $urandom % 32 : $urandom;   // many valid command bytes
                cs_n <= 0;
                if ($urandom % 2) begin wr_n <= 0; cmds <= cmds + 1; end else rd_n <= 0;
                hold <= 2 + $urandom % 6; phase <= 1;
            end
            1: begin cs_n <= 1; rd_n <= 1; wr_n <= 1; hold <= $urandom % 40; phase <= 0; end
            endcase
        end
        if (old.PROG_ROM_Q !== dut.PROG_ROM_Q || old.DATA_ROM_Q !== dut.DATA_ROM_Q || do_old !== do_new) begin
            if (errors < 5) $display("MISMATCH cyc %0d pc %h: prog %h/%h data %h/%h do %h/%h", cyc,
                old.PC, old.PROG_ROM_Q, dut.PROG_ROM_Q, old.DATA_ROM_Q, dut.DATA_ROM_Q, do_old, do_new);
            errors <= errors + 1;
        end
        if (!seen[old.PC]) begin seen[old.PC] <= 1; npc <= npc + 1; end
        cmp <= cmp + 1;
        if (cyc == 3000000) begin
            $display("VER %0d: %0d cycles compared, %0d CPU writes, %0d program addresses run, %0d mismatches -> %s",
                VER, cmp, cmds, npc, errors, errors == 0 ? "PASS" : "FAIL");
            $finish;
        end
    end
end
endmodule
