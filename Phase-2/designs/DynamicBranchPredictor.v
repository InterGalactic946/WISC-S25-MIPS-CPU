`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////////////////
// Dynamic Branch Predictor: Integrates BTB and BHT            //
//                                                             //
// This module combines a Branch Target Buffer (BTB) and a     //
// Branch History Table (BHT) to predict branch direction and  //
// fetch target addresses. The BHT provides a two-bit          //
// saturating counter-based prediction, while the BTB caches   //
// target addresses for taken branches.                        //
/////////////////////////////////////////////////////////////////
module DynamicBranchPredictor (
    input wire clk,                      // System clock
    input wire rst,                      // Active high reset signal
    input wire [15:0] PC_curr,           // Current PC address (16-bit)
    input wire [15:0] IF_ID_PC_curr,     // Pipelined previous PC address (16-bit)
    input wire is_branch,                // Indicates if the instruction is a branch (from the decode stage)
    input wire actual_taken,             // Actual branch taken value (from the decode stage)
    input wire [15:0] actual_target,     // Actual target address for the branch (from the decode stage)
    
    output wire predicted_taken,         // Predicted branch taken (from BHT)
    output wire [15:0] predicted_target  // Predicted target address (from BTB)
);

  // Write enables for both BHT and BTB
  wire wen_BTB, wen_BHT; 

  ////////////////////////////////////////////////
  // Instantiate the Branch Target Buffer (BTB) //
  ////////////////////////////////////////////////
  BTB iBTB (.clk(clk), .rst(rst), .PC_curr_lower(PC_curr[3:0]), .IF_ID_PC_curr_lower(IF_ID_PC_curr[3:0]), .wen(wen_BTB), .actual_target(actual_target),.predicted_target(predicted_target));

  ////////////////////////////////////////////////
  // Instantiate the Branch History Table (BHT) //
  ////////////////////////////////////////////////
  BHT iBHT (.clk(clk), .rst(rst), .PC_curr_lower(PC_curr[3:0]), .IF_ID_PC_curr_lower(IF_ID_PC_curr[3:0]), .wen(wen_BHT), .actual_taken(actual_taken),.predicted_taken(predicted_taken)); 

  // Update the BHT when the prediction doesn't match actual on a branch instruction.
  assign wen_BHT = (actual_taken != predicted_taken) & is_branch;

 // Update the BTB when branch is taken and it is a branch instruction.
  assign wen_BTB = actual_taken & is_branch;

endmodule

`default_nettype wire // Reset default behavior at the end
