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
module PipelineRegister (clk, rst, stall, flush, data_in, data_out);

  parameter WIDTH = 16;             // parametrize the amount of data to store in the register

  input wire clk;                   // System clock
  input wire rst;                   // Active high synchronous reset
  input wire stall;                 // Stall signal (prevents updates)
  input wire flush;                 // Flush pipeline register (clears the instruction)
  input wire [WIDTH-1:0] data_in;   // Input data from the previous pipeline stage
  output wire [WIDTH-1:0] data_out; // Output data to the next pipeline stage

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

  // Register for storing the previous.
  dff iPIPELINE_REG [WIDTH-1:0] (.q(data_out), .d(data_in), .wen({16{wen}}), .clk({16{clk}}), .rst({16{rst}}));

endmodule

`default_nettype wire // Reset default behavior at the end