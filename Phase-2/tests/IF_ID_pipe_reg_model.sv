`default_nettype none // Set the default as none to avoid errors
 
///////////////////////////////////////////////////////////////////////////
// IF_ID_pipe_reg_model.v: Model Instruction Fetch to Decode Pipeline    //
//                                                                       //
// This module represents a model IF/ID pipeline register for the CPU.   //
///////////////////////////////////////////////////////////////////////////
module IF_ID_pipe_reg_model (
    input logic clk,                   // System clock
    input logic rst,                   // Active high synchronous reset
    input logic stall,                 // Stall signal (prevents updates)
    input logic flush,                 // Flush pipeline register (clears the instruction word)
    input logic [15:0] PC_curr,        // Current PC from the fetch stage
    input logic [15:0] PC_next,        // Next PC from the fetch stage
    input logic [15:0] PC_inst,        // Current instruction word from the fetch sage
    input logic predicted_taken,       // Predicted branch taken signal from the fetch stage
    
    output logic [3:0] IF_ID_PC_curr,   // Pipelined lower 4-bits of current instruction address passed to the decode stage
    output logic [15:0] IF_ID_PC_next,  // Pipelined next PC passed to the decode stage
    output logic [15:0] IF_ID_PC_inst,  // Pipelined current instruction word passed to the decode stage
    output logic IF_ID_predicted_taken  // Pipelined predicted branch taken signal passed to the decode stage
);

  ///////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  logic wen; // Register write enable signal.
  logic clr; // Clear signal for instruction word register
  ///////////////////////////////////////////////

  ///////////////////////////////////////
  // Model the IF/ID Pipeline Register //
  ///////////////////////////////////////
  // We write to the register whenever we don't stall.
  assign wen = ~stall;
 
  // We clear the instruction word register whenever we flush or during rst.
  assign clr = flush | rst;

  // Model register for storing the current instruction's address.
  always @(posedge clk)
    if (rst)
      IF_ID_PC_curr <= 4'h0;
    else if (wen)
      IF_ID_PC_curr <= PC_curr[3:0];
  
  // Model register for storing the next instruction's address.
  always @(posedge clk)
    if (rst)
      IF_ID_PC_next <= 16'h0000;
    else if (wen)
      IF_ID_PC_next <= PC_next;
  
  // Model register for storing the fetched instruction word (clear the instruction on flush).
  always @(posedge clk)
    if (clr)
      IF_ID_PC_inst <= 16'h0000;
    else if (wen)
      IF_ID_PC_inst <= PC_inst;
  
  // Model register for storing the predicted branch taken signal (clear the signal on flush).
  always @(posedge clk)
    if (clr)
      IF_ID_predicted_taken <= 1'b0;
    else if (wen)
      IF_ID_predicted_taken <= predicted_taken;
  /////////////////////////////////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end