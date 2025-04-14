`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////
// Flag_Register.v: Flag register representing state  //
// This module infers a 3, 1-bit registers to hold    //
// and change the values of Z, V, and N flags.        //
////////////////////////////////////////////////////////
module Flag_Register(
  input wire clk,          // System clock
  input wire rst,          // active high reset signal
  input wire Z_en, Z_set,  // enable signal and set signal for Z
  input wire V_en, V_set,  // enable signal and set signal for V
  input wire N_en, N_set,  // enable signal and set signal for N
  output wire ZF,          // Z (Zero) signal flag
  output wire VF,          // V (Overflow) signal flag
  output wire NF           // N (Sign) signal flag
);

  // Infer the (Z) zero flag register.
  CPU_Register #(.WIDTH(1)) iZF_REG (.clk(clk), .rst(rst), .wen(Z_en), .data_in(Z_set), .data_out(ZF));

  // Infer the (V) overflow flag register.
  CPU_Register #(.WIDTH(1)) iVF_REG (.clk(clk), .rst(rst), .wen(V_en), .data_in(V_set), .data_out(VF));

  // Infer the (N) signed flag register.
  CPU_Register #(.WIDTH(1)) iNF_REG (.clk(clk), .rst(rst), .wen(N_en), .data_in(N_set), .data_out(NF));

endmodule

`default_nettype wire  // Reset default behavior at the end