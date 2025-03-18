//////////////////////////////////////////////////////////////
// Fetch_model.sv: Model Instruction Fetch Stage            //
//                                                          //
// This module models the fetch stage of the CPU            //
//////////////////////////////////////////////////////////////
module Fetch_model (
    input logic clk,                  // System clock
    input logic rst,                  // Active high synchronous reset
    input logic stall,                // Stall signal for the PC (from the hazard detection unit)
    input logic [15:0] actual_target, // Target address for branch instructions (from the decode stage)
    input logic actual_taken,         // Indicates whether the branch is actually taken (from the decode stage)
    input logic was_branch,           // Indicates that the previous instruction was a branch instruction
    input logic branch_mispredicted,  // Indicates if the branch prediction was incorrect (from the decode stage)
    input logic [3:0] IF_ID_PC_curr,  // Pipelined lower 4-bits of previous PC value (from the fetch stage)
    input logic loaded,              // Indicates that the instruction memory file is loaded
    
    output logic [15:0] PC_next,      // Computed next PC value
    output logic [15:0] PC_inst,      // Instruction fetched from the current PC address
    output logic [15:0] PC_curr,      // Current PC value
    output logic predicted_taken      // Predicted taken signal from the branch history table
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic [15:0] PC_new;           // The new address the PC is updated with.
  logic [15:0] predicted_target; // The predicted target address cached in the BTB
  logic [15:0] inst_mem [15:0];  // Models the instruction memory.
  logic enable;                  // Enables the reads/writes for PC, instruction memory, and BHT, BTB.
  ////////////////////////////////////////////////

  ///////////////////////////
  // Model the Fetch stage //
  ///////////////////////////
  // We write to the PC whenever we don't stall.
  assign enable = ~stall;

  // Update the PC with correct target on misprediction and taken, or the predicted target address 
  // if predicted to be taken, otherwise assume not taken.
  assign PC_new = (branch_mispredicted) ? 
                    ((actual_taken) ? actual_target : PC_next) : 
                    ((predicted_taken) ? predicted_target : PC_next);

  // Instantiate the Dynamic Branch Predictor model.
  DynamicBranchPredictor_model iDBP_model (
    .clk(clk), 
    .rst(rst), 
    .PC_curr(PC_curr[3:0]), 
    .IF_ID_PC_curr(IF_ID_PC_curr), 
    .enable(enable),
    .was_branch(was_branch),
    .actual_taken(actual_taken),
    .actual_target(actual_target),  
    .branch_mispredicted(branch_mispredicted), 
    
    .predicted_taken(predicted_taken), 
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
      if (!loaded) begin
        // Initialize the instruction memory on reset.
        $readmemh("./tests/instructions.img", inst_mem);
      end
    end
  end

  // Asynchronously read out the instruction when read enabled.
  assign PC_inst = (enable) ? inst_mem[PC_curr[15:1]] : 16'h0000;

  // Compute PC_next as the next instruction address.
  assign PC_next = PC_curr + 16'h0002;
  //////////////////////////////////////

endmodule