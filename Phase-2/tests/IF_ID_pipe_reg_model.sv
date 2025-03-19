///////////////////////////////////////////////////////////////////////////
// IF_ID_pipe_reg_model.sv: Model Instruction Fetch to Decode Pipeline   //
//                                                                       //
// This module represents a model IF/ID pipeline register for the CPU.   //
///////////////////////////////////////////////////////////////////////////
module IF_ID_pipe_reg_model (
    input wire clk,                   // System clock
    input wire rst,                   // Active high synchronous reset
    input wire stall,                 // Stall signal (prevents updates)
    input wire flush,                 // Flush pipeline register (clears the instruction word)
    input wire [15:0] PC_curr,        // Current PC from the fetch stage
    input wire [15:0] PC_next,        // Next PC from the fetch stage
    input wire [15:0] PC_inst,        // Current instruction word from the fetch stage
    input wire [1:0] prediction,      // The 2-bit predicted value of the current branch instruction from the fetch stage
    
    output wire [3:0] IF_ID_PC_curr,   // Pipelined lower 4-bits of current instruction address passed to the decode stage
    output wire [15:0] IF_ID_PC_next,  // Pipelined next PC passed to the decode stage
    output wire [15:0] IF_ID_PC_inst,  // Pipelined current instruction word passed to the decode stage
    output wire [1:0] IF_ID_prediction // Pipelined 2-bit branch prediction signal passed to the decode stage
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
      IF_ID_prediction <= 2'b00;
    else if (wen)
      IF_ID_prediction <= prediction;
  /////////////////////////////////////////////////////////////////////////////

endmodule