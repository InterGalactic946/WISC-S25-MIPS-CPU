//////////////////////////////////////////////////////////////
// Fetch_model.sv: Model Instruction Fetch Stage            //
//                                                          //
// This module models the fetch stage of the CPU            //
//////////////////////////////////////////////////////////////
module Fetch_model (
    input logic clk,                    // System clock
    input logic rst,                    // Active high synchronous reset
    input logic stall,                  // Stall signal for the PC (from the hazard detection unit)
    input logic actual_taken,           // Signal used to determine whether branch instruction met condition codes
    input logic wen_BHT,                // Write enable for BHT (Branch History Table)
    input logic [15:0] branch_target,   // 16-bit address of the branch target
    input logic wen_BTB,                // Write enable for BTB (Branch Target Buffer)
    input logic [15:0] actual_target,   // 16-bit address of the actual target
    input logic update_PC,              // Signal to update the PC with the actual target
    input logic [15:0] IF_ID_PC_curr,   // Pipelined lower 4-bits of previous PC value (from the fetch stage)
    input logic [1:0] IF_ID_prediction, // The predicted value of the previous branch instruction
    
    output logic [15:0] PC_next,         // Computed next PC value
    output logic [15:0] PC_inst,         // Instruction fetched from the current PC address
    output logic [15:0] PC_curr,         // Current PC value
    output logic [1:0] prediction,       // The 2-bit predicted value of the current branch instruction
    output logic [15:0] predicted_target // The predicted target from the BTB.
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic [15:0] PC_new;              // The new address the PC is updated with.
  logic [15:0] inst_mem [0:65535];  // Models the instruction memory.
  logic enable;                     // Enables the reads/writes for PC, instruction memory, and BHT, BTB.
  ////////////////////////////////////////////////

  ///////////////////////////
  // Model the Fetch stage //
  ///////////////////////////
  // We write to the PC whenever we don't stall.
  assign enable = ~stall;

  // Update the PC with correct target on misprediction or miscomputation on a taken branch, or the predicted target address 
  // if predicted to be taken, otherwise assume not taken.
  assign PC_new = (update_PC) ?  actual_target : ((prediction[1]) ? predicted_target : PC_next);

  // Instantiate the Dynamic Branch Predictor model.
  DynamicBranchPredictor_model iDBP_model (
    .clk(clk), 
    .rst(rst), 
    .PC_curr(PC_curr[3:0]), 
    .IF_ID_PC_curr(IF_ID_PC_curr), 
    .IF_ID_prediction(IF_ID_prediction), 
    .enable(enable),
    .wen_BTB(wen_BTB),
    .wen_BHT(wen_BHT),
    .actual_taken(actual_taken),
    .actual_target(branch_target),  
    
    .prediction(prediction), 
    .predicted_target(predicted_target)
  );

  // Model the PC register.
  always @(posedge clk)
    if (rst)
      PC_curr <= 16'h0000;
    else if (enable)
      PC_curr <= PC_new;

  // Model the instruction memory (read only).
  always @(posedge clk) begin
    if (rst) begin
      // Initialize the instruction memory on reset.
      $readmemh("./tests/instructions.img", inst_mem);
    end
  end

  // Asynchronously read out the instruction when read enabled.
  assign PC_inst = (enable) ? inst_mem[PC_curr[15:1]] : 16'h0000;

  // Compute PC_new as the next instruction address.
  assign PC_next = PC_curr + 16'h0002;
  //////////////////////////////////////

endmodule