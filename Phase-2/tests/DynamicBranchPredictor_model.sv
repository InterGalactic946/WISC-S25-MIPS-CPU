//////////////////////////////////////////////////////////////////
// DynamicBranchPredictor_model.sv: Model to the DBP of the CPU //
//                                                              //
// This module model the dynamic branch predictor of the CPU.   //
//////////////////////////////////////////////////////////////////

import Monitor_tasks::*;

module DynamicBranchPredictor_model (
    input logic clk,                      // System clock
    input logic rst,                      // Active high reset signal
    input logic [15:0] PC_curr,           // Current PC address
    input logic [15:0] IF_ID_PC_curr,     // Pipelined previous PC address
    input logic [1:0] IF_ID_prediction,   // The predicted value of the previous branch instruction.
    input logic enable,                   // Enable signal for the DynamicBranchPredictor
    input logic wen_BTB,                  // Write enable for BTB (Branch Target Buffer) (from the decode stage)
    input logic wen_BHT,                  // Write enable for BHT (Branch History Table) (from the decode stage)
    input logic actual_taken,             // Actual branch taken value (from the decode stage)
    input logic [15:0] actual_target,     // Actual target address for the branch (from the decode stage)

    output logic predicted_taken,         // Indicates if the branch is predicted taken (1) or not (0)
    output logic [1:0] prediction,        // 2-bit Predicted branch signal (from BHT)
    output logic [15:0] predicted_target  // Predicted target address (from BTB)
);
  
  ///////////////////////////////////////
  // Declare state types as enumerated //
  ///////////////////////////////////////
  typedef enum logic [1:0] {STRONG_NOT_TAKEN, WEAK_NOT_TAKEN, WEAK_TAKEN, STRONG_TAKEN} state_t;

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  state_t prev_prediction;        // Holds the previous prediction.
  state_t updated_prediction;     // The new prediction to be stored in the BHT on an incorrect prediction.
  logic tags_match;               // Used to determine if the current PC tag matches the previous PC tag cached in BHT.
  logic error;                    // Error flag raised when prediction state is invalid.
  model_BHT_t BHT [0:15];         // Declare BHT
  model_BTB_t BTB [0:15];         // Declare BTB
  ////////////////////////////////////////////////

  ////////////////////////////////////////
  // Model the Dynamic Branch Predictor //
  ////////////////////////////////////////
  // Model the BTB/BHT memory.
  always @(posedge clk) begin
      if (rst) begin
          // Initialize BHT: PC_addr = 'x, prediction = 2'b00
          BHT <= '{default: '{PC_addr: 16'hxxxx, prediction: 2'b00}};
          // Initialize BTB: PC_addr = 'x, target = 'x
          BTB <= '{default: '{PC_addr: 16'hxxxx, target: 16'h0000}};
      end 
      else begin
          // Update BHT entry if needed (for example, on a misprediction)
          if (enable && wen_BHT) begin
              BHT[IF_ID_PC_curr[3:1]].PC_addr  <= IF_ID_PC_curr;        // Store the PC address
              BHT[IF_ID_PC_curr[3:1]].prediction <= updated_prediction; // Store the 2-bit prediction along with the tag
          end

          // Update BTB entry if needed (when a branch is taken)
          if (enable && wen_BTB) begin
              BTB[IF_ID_PC_curr[3:1]].PC_addr <= IF_ID_PC_curr;  // Store the PC address
              BTB[IF_ID_PC_curr[3:1]].target  <= actual_target;  // Store the target address
          end
      end
  end

  // Asynchronously read out the prediction when read enabled.
  assign prediction = (enable & ~wen_BHT) ? BHT[PC_curr[3:1]].prediction : 2'h0;

    // Compare the tags of the current PC and previous PC address in the cache to determine if they match.
  assign tags_match = (PC_curr[15:4] == BHT[PC_curr[3:1]].PC_addr[15:4]);

  // If the tags match, use the prediction; otherwise, assume not taken.
  assign predicted_taken = (tags_match) ? prediction[1] : 1'b0; 

  // Asynchronously read out the target when read enabled.
  assign predicted_target = (enable & ~wen_BTB) ? BTB[PC_curr[3:1]].target : 16'h0000;
  //////////////////////////////////////////

  /////////////////////////////////
  // Model the prediction states //
  /////////////////////////////////
  // Cast the incoming previous prediction as of state type.
  assign prev_prediction = state_t'(IF_ID_prediction);

  always_comb begin
      error = 1'b0;                          // Default error state.
      updated_prediction = STRONG_NOT_TAKEN; // Default predict not taken.
      case (prev_prediction) // Update the new prediction based on the previous prediction.
          STRONG_NOT_TAKEN: updated_prediction = (actual_taken) ? WEAK_NOT_TAKEN : STRONG_NOT_TAKEN; // Stay in strong not taken or go to weak not taken
          WEAK_NOT_TAKEN: updated_prediction = (actual_taken) ? WEAK_TAKEN : STRONG_NOT_TAKEN; // Go to weak taken or go back to strong not taken
          WEAK_TAKEN: updated_prediction = (actual_taken) ? STRONG_TAKEN : WEAK_NOT_TAKEN; // Go to strong taken or go back to weak not taken
          STRONG_TAKEN: updated_prediction = (actual_taken) ? STRONG_TAKEN : WEAK_TAKEN; // Stay in strong taken or go back to weak taken
          default: begin
            updated_prediction = STRONG_NOT_TAKEN; // Default predict not taken.
            error = 1'b1;                          // Invalid prediction state.
          end
      endcase
  end
  ///////////////////////////////////

endmodule