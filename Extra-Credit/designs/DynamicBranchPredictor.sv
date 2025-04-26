//////////////////////////////////////////////////////////////////
// DynamicBranchPredictor_model.sv: Model to the DBP of the CPU //
//                                                              //
// This module model the dynamic branch predictor of the CPU.   //
//////////////////////////////////////////////////////////////////
module DynamicBranchPredictor (
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
  logic [1:0] prediction_rd;      // The prediction read out as it is from the memory.
  state_t prev_prediction;        // Holds the previous prediction.
  state_t updated_prediction;     // The new prediction to be stored in the BHT on an incorrect prediction.
  logic updated_valid;            // The updated valid bit for the branch.
  logic valid;                    // Indicates that the valid bit is set.
  logic [11:0] read_tag;          // The tag used for the current instruction as a read.
  logic [11:0] write_tag;         // The tag used for the previous instruction as a write.
  logic read_tags_match;          // Used to determine if the current PC tag matches the previous PC tag cached in BHT.
  logic write_tags_match;         // Used to determine if the current IF_ID_PC tag matches the previous PC tag cached in BHT.
  logic error;                    // Error flag raised when prediction state is invalid.
  logic [14:0] BHT [0:7];         // Declare BHT
  logic [15:0] BTB [0:7];         // Declare BTB
  ////////////////////////////////////////////////

  ////////////////////////////////////////
  // Model the Dynamic Branch Predictor //
  ////////////////////////////////////////
  // Model the BTB/BHT memory.
  always @(posedge clk) begin
      if (rst) begin
          // Initialize BHT: PC_tag = '0, prediction = STRONG_NOT_TAKEN, valid = 0
          BHT <= '{default: 15'h0000};
          // Initialize BTB: target = '0
          BTB <= '{default: 16'h0000};
      end 
      else begin
          // Update BHT entry if needed (for example, on a misprediction)
          if (enable && wen_BHT) begin
              BHT[IF_ID_PC_curr[3:1]][14:3]  <= IF_ID_PC_curr[15:4]; // Store the PC tag
              BHT[IF_ID_PC_curr[3:1]][2:1] <= updated_prediction;     // Store the 2-bit prediction along with the tag
              BHT[IF_ID_PC_curr[3:1]][0] <= updated_valid;            // Store the updated valid bit
          end

          // Update BTB entry if needed (when a branch is taken)
          if (enable && wen_BTB) begin
              BTB[IF_ID_PC_curr[3:1]]  <= actual_target;  // Store the target address
          end
      end
  end

  // Get the valid bit of the branch.
  assign valid = (enable) ? BHT[PC_curr[3:1]][0] : 1'b0;

  // Asynchronously read out the prediction when enabled.
  assign prediction_rd = (enable) ? BHT[PC_curr[3:1]][2:1] : 2'h0;

  // Read out the tag stored in the memory when enabled for a read.
  assign read_tag = (enable) ? BHT[PC_curr[3:1]][14:3] : 12'h000;

  // Compare the tags of the current PC and previous PC address in the cache to determine if they match.
  assign read_tags_match = (PC_curr[15:4] == read_tag);

  // If the read tags match and it is valid, use the prediction read out, else assume weak not taken.
  assign prediction = (read_tags_match & valid) ? prediction_rd : 2'h1; 

  // Take the taken flag as the MSB of the prediction.
  assign predicted_taken = prediction[1];

  // Asynchronously read out the target when enabled.
  assign predicted_target = (enable) ? BTB[PC_curr[3:1]] : 16'h0000;
  //////////////////////////////////////////

  /////////////////////////////////
  // Model the prediction states //
  /////////////////////////////////
  // Cast the incoming previous prediction as of state type.
  assign prev_prediction = state_t'(IF_ID_prediction);

  // Read out the tag stored in the memory when enabled for a write.
  assign write_tag = (enable) ? BHT[IF_ID_PC_curr[3:1]][14:3] : 12'h000;

  // Check if the write tags match for the current IF_ID_PC and the previous PC address in the cache.
  assign write_tags_match = (IF_ID_PC_curr[15:4] == write_tag);

  always_comb begin
      error = 1'b0;                          // Default error state.
      updated_prediction = STRONG_NOT_TAKEN; // Default predict not taken.
      updated_valid = 1'b0;                  // Default assume invalid.
      case (prev_prediction) // Update the new prediction based on the previous prediction.
            STRONG_NOT_TAKEN: begin
                updated_valid = 1'b1;                                                       // Set the valid bit as it is a valid branch instruction
                if(write_tags_match) begin // If the tags match, update the prediction.
                    updated_prediction = (actual_taken) ? WEAK_NOT_TAKEN : STRONG_NOT_TAKEN; // Go to weak not taken or stay in strong not taken
                end else begin // If the tags do not match, assume not taken.
                    updated_prediction = WEAK_NOT_TAKEN; // Default predict weak not taken.
                end
            end
            WEAK_NOT_TAKEN: begin // Default state
                updated_valid = 1'b1;                                                    // Set the valid bit as it is a valid branch instruction
                updated_prediction = (actual_taken) ? WEAK_TAKEN : STRONG_NOT_TAKEN;     // Go to weak taken or back to strong not taken
            end
            WEAK_TAKEN: begin
                updated_valid = 1'b1;                                                       // Set the valid bit as it is a valid branch instruction
                if(write_tags_match) begin // If the tags match, update the prediction.
                    updated_prediction = (actual_taken) ? STRONG_TAKEN : WEAK_NOT_TAKEN;    // Go to strong taken or go back to weak not taken
                end else begin // If the tags do not match, assume not taken.
                    updated_prediction = WEAK_NOT_TAKEN; // Default predict weak not taken.
                end
            end
            STRONG_TAKEN: begin
                updated_valid = 1'b1;                                                    // Set the valid bit as it is a valid branch instruction
                if(write_tags_match) begin // If the tags match, update the prediction.
                    updated_prediction = (actual_taken) ? STRONG_TAKEN : WEAK_TAKEN;     // Stay in strong taken or go back to weak taken
                end else begin // If the tags do not match, assume not taken.
                    updated_prediction = WEAK_NOT_TAKEN; // Default predict weak not taken.
                end
            end
            default: begin
                updated_valid = 1'b0;                  // Default assume invalid.
                updated_prediction = STRONG_NOT_TAKEN; // Default predict not taken.
                error = 1'b1;                          // Invalid prediction state.
            end
      endcase
  end
  ///////////////////////////////////

endmodule