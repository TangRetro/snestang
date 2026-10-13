// Behavioural stand-in for the Gowin DPB wrapper (2048 x 16, bypass read, normal write).
// Old and new DSPn both use it, so the comparison does not depend on its exact timing.
module dsp_data_ram (douta, doutb, clka, ocea, cea, reseta, wrea, clkb, oceb, ceb, resetb, wreb, ada, dina, adb, dinb);
output reg [15:0] douta, doutb;
input clka, ocea, cea, reseta, wrea, clkb, oceb, ceb, resetb, wreb;
input [10:0] ada, adb;
input [15:0] dina, dinb;
reg [15:0] m [2048];
initial for (int i = 0; i < 2048; i++) m[i] = 0;
always @(posedge clka) if (cea) begin if (wrea) begin m[ada] <= dina; douta <= dina; end else douta <= m[ada]; end
always @(posedge clkb) if (ceb) begin if (wreb) begin m[adb] <= dinb; doutb <= dinb; end else doutb <= m[adb]; end
endmodule
