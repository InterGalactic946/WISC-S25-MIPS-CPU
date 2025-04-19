///////////////////////////////////////////////////////////////////////////
// IF_ID_pipe_reg_model.sv: Model Instruction Fetch to Decode Pipeline   //
//                                                                       //
// This module represents a model IF/ID pipeline register for the CPU.  //
///////////////////////////////////////////////////////////////////////////
module IF_ID_pipe_reg_model (
    input logic clk,                     // System clock
    input logic rst,                     // Active high synchronous reset
    input logic stall,                   // Stall signal (prevents updates)
    input logic flush,                   // Flush pipeline register (clears the instruction word)
    input logic [15:0] PC_curr,          // Current PC from the fetch stage
    input logic [15:0] PC_next,          // Next PC from the fetch stage
    input logic [15:0] PC_inst,          // Current instruction word from the fetch stage
    input logic [1:0]  prediction,       // The 2-bit predicted value of the current branch instruction from the fetch stage
    input logic [15:0] predicted_target, // The predicted target from the BTB.

    output logic [15:0] IF_ID_PC_curr,           // Pipelined current instruction address passed to the decode stage
    output logic [15:0] IF_ID_PC_next,           // Pipelined next PC passed to the decode stage
    output logic [15:0] IF_ID_PC_inst,           // Pipelined current instruction word passed to the decode stage
    output logic [1:0]  IF_ID_prediction,        // Pipelined 2-bit branch prediction signal passed to the decode stage
    output logic [15:0] IF_ID_predicted_target,  // Pipelined predicted target passed to the decode stage
  );

  ///////////////////////////////////////////////
  // Declare any internal signals as type logic//
  ///////////////////////////////////////////////
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
  always_ff @(posedge clk)
    if (rst)
      IF_ID_PC_curr <= 16'h0000;
    else if (wen)
      IF_ID_PC_curr <= PC_curr;
  
  // Model register for storing the next instruction's address.
  always_ff @(posedge clk)
    if (rst)
      IF_ID_PC_next <= 16'h0000;
    else if (wen)
      IF_ID_PC_next <= PC_next;
  
  // Model register for storing the fetched instruction word (clear the instruction on flush).
  always_ff @(posedge clk)
    if (clr)
      IF_ID_PC_inst <= 16'h0000;
    else if (wen)
      IF_ID_PC_inst <= PC_inst;
  
  // Model register for storing the predicted branch taken signal (clear the signal on flush).
  always_ff @(posedge clk)
    if (clr)
      IF_ID_prediction <= 2'b00;
    else if (wen)
      IF_ID_prediction <= prediction;
  
  // Model register for storing the predicted target address (clear the data on flush).
  always_ff @(posedge clk)
    if (clr)
      IF_ID_predicted_target <= 16'h0000;
    else if (wen)
      IF_ID_predicted_target <= predicted_target;

  // Model register for storing the first LRU tag (clear on flush).
  always_ff @(posedge clk)
    if (clr)
      IF_ID_first_tag_LRU <= 1'b0';
    else if (wen)
      IF_ID_first_tag_LRU <= first_tag_LRU;

  // Model register for storing the first matched tag (clear on flush).
  always_ff @(posedge clk)
    if (clr)
      IF_ID_first_match <= 16'h0000;
    else if (wen)
      IF_ID_first_match <= first_match;

  // Model register for storing the I-Cache hit signal (clear on flush).
  always_ff @(posedge clk)
    if (clr)
      IF_ID_ICACHE_hit <= 1'b0;
    else if (wen)
      IF_ID_ICACHE_hit <= hit;
  /////////////////////////////////////////////////////////////////////////////

endmodule
