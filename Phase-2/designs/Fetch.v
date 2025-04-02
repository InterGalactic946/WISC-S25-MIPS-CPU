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
    input wire clk,                    // System clock
    input wire rst,                    // Active high synchronous reset
    input wire stall,                  // Stall signal for the PC (from the hazard detection unit)
    input wire actual_taken,           // Signal used to determine whether branch instruction met condition codes
    input wire wen_BHT,                // Write enable for BHT (Branch History Table)
    input wire [15:0] branch_target,   // 16-bit address of the branch target
    input wire wen_BTB,                // Write enable for BTB (Branch Target Buffer)
    input wire [15:0] actual_target,   // 16-bit address of the actual target
    input wire update_PC,              // Signal to update the PC with the actual target
    input logic [15:0] IF_ID_PC_curr,  // Pipelined previous PC value (from the fetch stage)
    input wire [1:0] IF_ID_prediction, // The predicted value of the previous branch instruction
    
    output wire [15:0] PC_next,         // Computed next PC value
    output wire [15:0] PC_inst,         // Instruction fetched from the current PC address
    output wire [15:0] PC_curr,         // Current PC value
    output wire [1:0] prediction,       // The 2-bit predicted value of the current branch instruction
    output wire [15:0] predicted_target // The predicted target from the BTB.
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire predicted_taken;  // The predicted value of the current instruction.
  wire [15:0] PC_new;    // The new address the PC is updated with.
  wire enable;           // Enables the reads/writes for PC, instruction memory, and BHT, BTB.
  ////////////////////////////////////////////////

  //////////////////////////////////////////////////////////
  // Implement PC_control as structural/dataflow verilog //
  ////////////////////////////////////////////////////////
  // We write to the PC whenever we don't stall.
  assign enable = ~stall;

  // Update the PC with correct target on misprediction or miscomputation on a taken branch, or the predicted target address 
  // if predicted to be taken, otherwise assume not taken.
  assign PC_new = (update_PC) ? actual_target : ((predicted_taken) ? predicted_target : PC_next);

  // Instantiate the Dynamic Branch Predictor to get the target branch address cached in the BTB before the decode stage.
  DynamicBranchPredictor iDBP (
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