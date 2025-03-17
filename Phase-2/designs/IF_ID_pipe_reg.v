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
    input wire clk,                   // System clock
    input wire rst,                   // Active high synchronous reset
    input wire stall,                 // Stall signal (prevents updates)
    input wire flush,                 // Flush pipeline register (clears the instruction word)
    input wire [15:0] PC_curr,        // Current PC from the fetch stage
    input wire [15:0] PC_next,        // Next PC from the fetch stage
    input wire [15:0] PC_inst,        // Current instruction word from the fetch sage
    input wire predicted_taken,       // Predicted branch taken signal from the fetch stage
    
    output wire [3:0] IF_ID_PC_curr,   // Pipelined lower 4-bits of current instruction address from the fetch stage
    output wire [15:0] IF_ID_PC_next,  // Pipelined next PC passed to the decode stage
    output wire [15:0] IF_ID_PC_inst,  // Pipelined current instruction word passed to the decode stage
    output wire IF_ID_predicted_taken  // Pipelined predicted branch taken signal passed to the decode stage
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire wen; // Register write enable signal.
  wire clr; // Clear signal for instruction word register
  ///////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////
  // Implement the IF/ID Pipeline Register as structural/dataflow verilog //
  /////////////////////////////////////////////////////////////////////////
  // We write to the register whenever we don't stall.
  assign wen = ~stall;
 
  // We clear the instruction word register whenever we flush or during rst.
  assign clr = flush | rst;

  // Register for storing the current instruction's address.
  CPU_Register #(.WIDTH(4)) iPC_CURR_REG (.clk(clk), .rst(rst), .wen(wen), .data_in(PC_curr[3:0]), .data_out(IF_ID_PC_curr));

  // Register for storing the next instruction's address.
  CPU_Register iPC_NEXT_REG (.clk(clk), .rst(rst), .wen(wen), .data_in(PC_next), .data_out(IF_ID_PC_next));

  // Register for storing the fetched instruction word (clear the instruction on flush).
  CPU_Register iPC_INST_REG (.clk(clk), .rst(clr), .wen(wen), .data_in(PC_inst), .data_out(IF_ID_PC_inst));

  // Register for storing the predicted branch taken signal (clear the signal on flush).
  CPU_Register #(.WIDTH(1)) iPREDICTED_TAKEN_REG (.clk(clk), .rst(clr), .wen(wen), .data_in(predicted_taken), .data_out(IF_ID_predicted_taken));

endmodule

`default_nettype wire // Reset default behavior at the end