//////////////////////////////////////////////////////////////
// Fetch_model.sv: Model Instruction Fetch Stage            //
//                                                          //
// This module models the fetch stage of the CPU            //
//////////////////////////////////////////////////////////////
module Fetch_model (
    input logic clk,                    // System clock
    input logic rst,                    // Active high synchronous reset
    input logic stall,                  // Stall signal for the PC (from the hazard detection unit)
    input logic hlt_fetched,            // Indicates if the fetched instruction is a halt instruction.
    input logic actual_taken,           // Signal used to determine whether branch instruction met condition codes
    input logic wen_BHT,                // Write enable for BHT (Branch History Table)
    input logic [15:0] branch_target,   // 16-bit address of the branch target
    input logic wen_BTB,                // Write enable for BTB (Branch Target Buffer)
    input logic [15:0] actual_target,   // 16-bit address of the actual target
    input logic update_PC,              // Signal to update the PC with the actual target
    input logic [15:0] IF_ID_PC_curr,   // Pipelined previous PC value (from the fetch stage)
    input logic [1:0] IF_ID_prediction, // The predicted value of the previous branch instruction
    
    output logic [15:0] PC_next,         // Computed next PC value
    output logic [15:0] PC_curr,         // Current PC value
    output logic [1:0] prediction,       // The 2-bit predicted value of the current branch instruction
    output logic [15:0] predicted_target // The predicted target from the BTB.
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic predicted_taken;            // The predicted value of the current instruction.
  logic enable;                     // Enables the reads/writes for PC, instruction memory, and BHT, BTB.
  logic [15:0] PC_target;           // The target address of the branch instruction from the BTB or the next PC.
  logic [15:0] PC_new;              // The PC is updated with the current PC if HLT is fetched, or the target address otherwise.
  logic [15:0] PC_update;           // The address to update the PC with.
  ////////////////////////////////////////////////

  ///////////////////////////
  // Model the Fetch stage //
  ///////////////////////////
  // We write to the PC whenever we don't stall on decode.
  assign enable = ~stall;

  // Get the branch instruction address from the BTB, if predicted to be taken, else it is PC + 2.
  assign PC_target = (predicted_taken) ? predicted_target : PC_next;

  // Get the new PC with the current PC if HLT is fetched, or the target address otherwise.
  assign PC_new = (hlt_fetched) ? PC_curr : PC_target;

  // Update the PC with correct target on misprediction or the new PC otherwise.
  assign PC_update = (update_PC) ? actual_target : PC_new;

  // Instantiate the Dynamic Branch Predictor model.
  DynamicBranchPredictor_model iDBP_model (
    .clk(clk), 
    .rst(rst), 
    .PC_curr(PC_curr), 
    .IF_ID_PC_curr(IF_ID_PC_curr), 
    .IF_ID_prediction(IF_ID_prediction), 
    .enable(enable),
    .wen_BTB(wen_BTB),
    .wen_BHT(wen_BHT),
    .actual_taken(actual_taken),
    .actual_target(branch_target),  
    
    .predicted_taken(predicted_taken),
    .prediction(prediction), 
    .predicted_target(predicted_target)
  );

  // Model the PC register.
  always @(posedge clk)
    if (rst)
      PC_curr <= 16'h0000;
    else if (enable)
      PC_curr <= PC_update;

  // Compute PC_new as the next instruction address.
  assign PC_next = PC_curr + 16'h0002;
  //////////////////////////////////////

endmodule