//////////////////////////////////////////////////////////////////
// DynamicBranchPredictor_model.sv: Model to the DBP of the CPU //
//                                                              //
// This module model the dynamic branch predictor of the CPU.   //
//////////////////////////////////////////////////////////////////
module DynamicBranchPredictor_model (
    input logic clk,                      // System clock
    input logic rst,                      // Active high reset signal
    input logic [3:0] PC_curr,            // Lower 4-bits of current PC address
    input logic [3:0] IF_ID_PC_curr,      // Pipelined lower 4-bits of previous PC address
    input wire [1:0] IF_ID_prediction,    // The predicted value of the previous branch instruction.
    input logic enable,                   // Enable signal for the DynamicBranchPredictor
    input wire wen_BTB,                  // Write enable for BTB (Branch Target Buffer) (from the decode stage)
    input wire wen_BHT,                  // Write enable for BHT (Branch History Table) (from the decode stage)
    input logic actual_taken,             // Actual branch taken value (from the decode stage)
    input logic [15:0] actual_target,     // Actual target address for the branch (from the decode stage)

    output logic [1:0] prediction,        // 2-bit Predicted branch signal (from BHT)
    output logic [15:0] predicted_target  // Predicted target address (from BTB)
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic [1:0] updated_prediction; // The new prediction to be stored in the BHT on an incorrect prediction.
  logic [1:0] BHT [15:0];         // 2-bit, 16 entry Branch History Table (BHT) memory.
  logic [15:0] BTB [15:0];        // 16 entry Branch Target Buffer (BTB) memory.
  logic error;                    // Error flag raised when prediction state is invalid.
  ////////////////////////////////////////////////

  ///////////////////////////////////////////
  // Model the Branch Target Buffer (BTB) //
  /////////////////////////////////////////
  // Model the BTB memory.
  always @(posedge clk) begin
    if (rst) begin
      // Initialize the BTB entries to a default target address (e.g., 16'h0000).
      BTB <= '{default: 16'h0000};
    end else if (enable & wen_BTB) begin
      // Update BTB with the target address if the branch was taken.
      BTB[IF_ID_PC_curr[3:1]] <= actual_target;
    end
  end

  // Asynchronously read out the target when read enabled.
  assign predicted_target = (enable & ~wen_BTB) ? BTB[PC_curr[3:1]] : 16'h0000;
  ////////////////////////////////////////////////

  ///////////////////////////////////////////
  // Model the Branch History Table (BHT) //
  /////////////////////////////////////////
  // Model the BHT memory.
  always @(posedge clk) begin
    if (rst) begin
      // Initialize the BHT entries to 0 on reset.
      BHT <= '{default: 2'h0};
    end else if (enable & wen_BHT) begin
      // Update BHT based on a mispredicted branch instruction.
      BHT[IF_ID_PC_curr[3:1]] <= updated_prediction;
    end
  end

  // Asynchronously read out the prediction when read enabled.
  assign prediction = (enable & ~wen_BHT) ? BHT[PC_curr[3:1]] : 2'h0;
 
  // Model the prediction states.
  always_comb begin
      error = 1'b0;              // Default error state.
      updated_prediction = 2'h0; // Default predict not taken.
      case (IF_ID_prediction)
          2'h0: updated_prediction = (actual_taken) ? 2'h1 : 2'h0; // Strong Not Taken
          2'h1: updated_prediction = (actual_taken) ? 2'h2 : 2'h1; // Weak Not Taken
          2'h2: updated_prediction = (actual_taken) ? 2'h3 : 2'h2; // Weak Taken
          2'h3: updated_prediction = (actual_taken) ? 2'h3 : 2'h2; // Strong Taken
          default: begin
            updated_prediction = 2'h0; // Default predict not taken.
            error = 1'b1;              // Invalid prediction state.
          end
      endcase
  end
  ////////////////////////////////////////////////

endmodule