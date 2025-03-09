`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////////
// flag_register.v                                    //
// This module infers a 3-bit register to hold and   //
// change the values of Z, V, and N signals.        //
/////////////////////////////////////////////////////
module flag_register(
  input wire clk,          // System clock
  input wire rst,          // active high reset signal
  input wire Z_en, Z_set,  // enable signal and set signal for Z
  input wire V_en, V_set,  // enable signal and set signal for V
  input wire N_en, N_set,  // enable signal and set signal for N
  output wire Z,           // Z (Zero) signal
  output wire V,           // V (Overflow) signal
  output wire N            // N (Sign) signal
);

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

`default_nettype wire  // Reset default behavior at the end