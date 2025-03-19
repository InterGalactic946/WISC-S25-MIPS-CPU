`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////////////////
// DynamicBranchPredictor.v: Integrates BTB and BHT            //
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
    input wire [3:0] PC_curr,            // Lower 4-bits of current PC address
    input wire [3:0] IF_ID_PC_curr,      // Pipelined lower 4-bits of previous PC address
    input wire [1:0] IF_ID_prediction,   // The predicted value of the previous branch instruction.
    input wire enable,                   // Enable signal for the DynamicBranchPredictor
    input wire wen_BTB,                  // Write enable for BTB (Branch Target Buffer) (from the decode stage)
    input wire wen_BHT,                  // Write enable for BHT (Branch History Table) (from the decode stage)
    input wire actual_taken,             // Actual branch taken value (from the decode stage)
    input wire [15:0] actual_target,     // Actual target address for the branch (from the decode stage)

    output wire [1:0] prediction,        // The 2-bit predicted value of the current branch instruction.
    output wire [15:0] predicted_target  // Predicted target address (from BTB)
);

  ////////////////////////////////////////////////
  // Instantiate the Branch Target Buffer (BTB) //
  ////////////////////////////////////////////////
  // Instantiate the branch target buffer.
  BTB iBTB (
    .clk(clk), 
    .rst(rst), 
    .enable(enable),
    .PC_curr(PC_curr), 
    .IF_ID_PC_curr(IF_ID_PC_curr), 
    .wen(wen_BTB), 
    .actual_target(actual_target),
    
    .predicted_target(predicted_target)
  );
  ////////////////////////////////////////////////

  ////////////////////////////////////////////////
  // Instantiate the Branch History Table (BHT) //
  ////////////////////////////////////////////////
  // We update the BHT on a mispredicted branch instruction.  
  BHT iBHT (
    .clk(clk), 
    .rst(rst), 
    .enable(enable),
    .PC_curr(PC_curr), 
    .IF_ID_PC_curr(IF_ID_PC_curr),
    .IF_ID_prediction(IF_ID_prediction), 
    .wen(wen_BHT), 
    .actual_taken(actual_taken),
    
    .prediction(prediction)
  ); 
  ////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end
