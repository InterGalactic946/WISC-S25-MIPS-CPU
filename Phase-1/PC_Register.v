`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////
// PC_Register.v                                  //
// This module implements a register to hold the //
// current value of the address and updates the //
// register on every clock cycle               //
////////////////////////////////////////////////
module PC_Register(
  input wire clk,             // System clock
  input wire rst,             // Active high synchronous reset
  input wire [15:0] nxt_pc,   // Next pc address
  output wire [15:0] curr_pc  // Current pc address
);

  ////////////////////////////////////////
  // Instantiate 16 flops for register //
  //////////////////////////////////////
  dff iFF [15:0] (.q(curr_pc), .d(nxt_pc), .wen(16'hFFFF), .clk({16{clk}}), .rst({16{rst}}));

endmodule

`default_nettype wire  // Reset default behavior at the end