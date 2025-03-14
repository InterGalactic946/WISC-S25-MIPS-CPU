`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////////
// IF_ID_pipe_reg.v: Instruction Fetch to Decode Pipeline    //
//                                                           //
// This module represents the pipeline register between the  //
// Instruction Fetch (IF) stage and the Instruction Decode   //
// (ID) stage. It holds the Program Counter (PC) and the     //
// fetched instruction while passing them from the IF stage  //
// to the ID stage.                                          //
///////////////////////////////////////////////////////////////
module IF_ID_pipe_reg (
    input wire clk,                     // System clock
    input wire rst,                     // Active high synchronous reset
    input wire stall,                   // Stall signal (prevents updates)
    input wire flush,                   // Flush pipeline register (clears the instruction word)
    input wire [15:0] PC_next_in,       // Next PC from Fetch stage
    input wire [15:0] PC_inst_in,       // Fetched instruction
    output wire [15:0] PC_next_out,     // Next PC passed to the decode stage
    output wire [15:0] PC_inst_out      // Instruction word passed to the decode stage
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire wen;   // Register write enable signal.
  wire clr;   // Clear signal for instruction word register
  //////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////
  // Implement the IF/ID Pipeline Register as structural/dataflow verilog //
  /////////////////////////////////////////////////////////////////////////
  // We write to the register whenever we don't stall.
  assign wen = ~stall;

  // We clear the instruction word register whenever we flush or during rst.
  assign clr = flush | rst;

  // Register for storing the next instruction's address.
  dff iPC_next [15:0] (.q(PC_next_out), .d(PC_next_in), .wen({16{wen}}), .clk({16{clk}}), .rst({16{rst}}));

  // Register for storing the fetched instruction word.
  dff iPC_inst [15:0] (.q(PC_inst_out), .d(PC_inst_in), .wen({16{wen}}), .clk({16{clk}}), .rst({16{clr}}));

endmodule

`default_nettype wire // Reset default behavior at the end