/////////////////////////////////////////////////////
// PC_Register.v                                  //
// This module implements a register to hold the //
// current value of the address and updates the //
// register on every clock cycle               //
////////////////////////////////////////////////
module PC_Register(
  input clk,             // System clock
  input rst,             // Active high reset
  input [15:0] nxt_pc,   // Next pc address
  output [15:0] curr_pc  // Current pc address
);

  ////////////////////////////////////////
  // Instantiate 16 flops for register //
  //////////////////////////////////////
  dff iFF [15:0] (.q(curr_pc), .d(nxt_pc), .wen(16'hFFFF), .clk(clk), .rst(rst));

endmodule