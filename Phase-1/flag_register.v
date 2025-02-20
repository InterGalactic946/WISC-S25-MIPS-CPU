/////////////////////////////////////////////////////////
// flag_register.v                                    //
// This module creates a register to hold and change //
// the values of Z, V, and N signals                //
/////////////////////////////////////////////////////
module flag_register(
  input clk,          // System clock
  input rst,          // active high reset signal
  input Z_en, Z_set,  // enable signal and set signal for Z
  input V_en, V_set,  // enable signal and set signal for V
  input N_en, N_set,  // enable signal and set signal for N
  output Z,           // Z (Zero) signal
  output V,           // V (Overflow) signal
  output N            // N (Sign) signal
)

  ///////////////////////////////////////
  // Flop each singal based on enable //
  /////////////////////////////////////
  // flop for Z (Zero) signal
  dff iFFZ (.q(Z), .d(Z_set), .wen(Z_en), .clk(clk), .rst(rst));

  // flop for V (Overflow) signal
  dff iFFV (.q(V), .d(V_set), .wen(V_en), .clk(clk), .rst(rst));

  // flop for N (Sign) signal
  dff iFFN (.q(N), .d(N_set), .wen(N_en), .clk(clk), .rst(rst));

endmodule