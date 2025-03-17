`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////////////
// Fetch.v: Instruction Fetch Stage                         //
//                                                          //
// This module implements the instruction fetch stage of    //
// the pipeline. It manages the Program Counter (PC) and    //
// determines the next instruction address using branch     //
// prediction. The module includes logic to choose between  //
// sequential execution (PC + 2) and branch targets based   //
// on predictions from the Branch Predictor.                //
//////////////////////////////////////////////////////////////
module Fetch (
    input wire clk,                  // System clock
    input wire rst,                  // Active high synchronous reset
    input wire stall,                // Stall signal for the PC (from the hazard detection unit)
    input wire [15:0] actual_target, // Target address for branch instructions (from the decode stage)
    input wire actual_taken,         // Indicates whether the branch is actually taken (from the decode stage)
    input wire was_branch,           // Indicates that the previous instruction was a branch instruction
    input wire branch_mispredicted,  // Indicates if the branch prediction was incorrect (from the decode stage)
    input wire [3:0] IF_ID_PC_curr,  // Pipelined lower 4-bits of previous PC value (from the fetch stage)
    
    output wire [15:0] PC_next,      // Computed next PC value
    output wire [15:0] PC_inst,      // Instruction fetched from the current PC address
    output wire [15:0] PC_curr,      // Current PC value
    output wire predicted_taken      // Predicted taken signal from the branch history table
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire [15:0] PC_new;           // The new address the PC is updated with.
  wire [15:0] predicted_target; // The predicted target address cached in the BTB
  wire enable;                  // Enables the reads/writes for PC, instruction memory, and BHT, BTB.
  ////////////////////////////////////////////////

  //////////////////////////////////////////////////////////
  // Implement PC_control as structural/dataflow verilog //
  ////////////////////////////////////////////////////////
  // We write to the PC whenever we don't stall.
  assign enable = ~stall;

  // Update the PC with correct target on misprediction and taken, or the predicted target address 
  // if predicted to be taken, otherwise assume not taken.
  assign PC_new = (branch_mispredicted) ? 
                    ((actual_taken) ? actual_target : PC_next) : 
                    ((predicted_taken) ? predicted_target : PC_next);

  // Instantiate the Dynamic Branch Predictor to get the target branch address cached in the BTB before the decode stage.
  DynamicBranchPredictor iDBP (
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

  // Infer the PC Register.
  CPU_Register iPC (.clk(clk), .rst(rst), .wen(enable), .data_in(PC_new), .data_out(PC_curr));

  // Infer the instruction memory, it is read enabled when not stalling and never write enabled.
  memory1c iINSTR_MEM (.data_out(PC_inst),
                       .data_in(16'h0000),
                        .addr(PC_curr),
                        .enable(enable),
                        .data(1'b0),
                        .wr(1'b0),
                        .clk(clk),
                        .rst(rst)
                      );

  // Instantiate the PC+2 adder.
  CLA_16bit iCLA_next (.A(PC_curr), .B(16'h0002), .sub(1'b0), .Sum(PC_next), .Cout(), .Ovfl(), .pos_Ovfl(), .neg_Ovfl());

endmodule

`default_nettype wire // Reset default behavior at the end