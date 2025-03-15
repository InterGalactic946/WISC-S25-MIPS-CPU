`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////
// Flag_Register.v: Flag register representing state  //
// This module infers a 3, 1-bit registers to hold    //
// and change the values of Z, V, and N flags.        //
////////////////////////////////////////////////////////
module Flag_Register(
  input wire clk,             // System clock
  input wire rst,             // active high reset signal
  input wire [2:0] wen,       // write enable signal for each 1-bit register (Z_en, NV_en, NV_en)
  input wire [2:0] flags_in,  // 3-bit flags as input to the register (Z_set, V_set, N_set)
  output wire [2:0] flags_out // 3-bit flags read out of the register (ZF, VF, NF)
);

  // Infer the flag Register as an array of 1-bit registers.
  CPU_Register #(.WIDTH(1)) iFLAG_REG [2:0] (.clk({3{clk}}), .rst({3{rst}}), .wen(wen), .data_in(flags_in), .data_out(flags_out));

endmodule

`default_nettype wire  // Reset default behavior at the end