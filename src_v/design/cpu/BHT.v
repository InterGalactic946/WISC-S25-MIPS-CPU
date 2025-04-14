`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////////////
// BHT.v: 16-entry, 2-bit Branch History Table             //
//                                                         //
// This design implements a 16-entry BHT, with each entry  //
// being a 2-bit register. It allows reading and updating  //
// predictions based on the branch PC address.             //
/////////////////////////////////////////////////////////////
module BHT (
    input wire clk,                     // System clock
    input wire rst,                     // active high reset signal
    input wire [15:0] PC_curr,          // Current PC from the fetch stage
    input wire [15:0] IF_ID_PC_curr,    // Pipelined previous PC from the fetch stage
    input wire [1:0] IF_ID_prediction,  // The predicted value of the previous branch instruction
    input wire wen,                     // used to update the BTB memory on a misprediction
    input wire enable,                  // Enable signal for the BHT
    input wire actual_taken,            // Actual taken value (from the decode stage)
    
    output wire taken,                  // Indicates if the branch is predicted taken (1) or not (0)
    output wire [1:0] prediction        // The 2-bit predicted value of the current branch instruction.
  );

  ///////////////////////////////////////////
  // Declare any internal signals as wire  //
  ///////////////////////////////////////////
  reg [13:0] updated_prediction;   // The new prediction to be stored in the BHT on an incorrect prediction.
  wire [13:0] prediction_ext_curr; // The 14-bit predicted value of the current branch instruction.
  wire [13:0] prediction_ext_prev; // The 14-bit predicted value of the previous branch instruction.
  wire read_tags_match;            // Used to determine if the current PC tag matches the previous PC tag cached in BHT.
  wire write_tags_match;           // Used to determine if the current IF_ID_PC tag matches the previous PC tag cached in BHT.
  reg error;                       // Error flag raised when prediction state is invalid.
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////
  // Implement BHT as structural/dataflow verilog //
  //////////////////////////////////////////////////
  // Infer the branch history table as an asynchronously read, synchronously written memory, enabled when not stalling.
  Branch_Cache #(14) iMEM_BHT (
                    .clk(clk),
                    .rst(rst),
                    .SrcCurr(PC_curr[3:1]),
                    .SrcPrev(IF_ID_PC_curr[3:1]),
                    .DstPrev(IF_ID_PC_curr[3:1]),
                    .enable(enable),
                    .wen(wen),
                    .DstData(updated_prediction),
                    .SrcDataCurr(prediction_ext_curr),
                    .SrcDataPrev(prediction_ext_prev)
                  );
  
  // Output the current prediction as the lower 2 bits of the prediction_ext.
  assign prediction = prediction_ext_curr[1:0];

  // Compare the tags of the current PC and previous PC address in the cache to determine if they match.
  assign read_tags_match = (PC_curr[15:4] == prediction_ext_curr[13:2]);

  // If the read tags match, use the prediction; otherwise, assume not taken.
  assign taken = (read_tags_match) ? prediction[1] : 1'b0; 
  ///////////////////////////////////////////////////

  //////////////////////////////////////////////////////
  // Update the prediction based on the current state //
  //////////////////////////////////////////////////////
  // Compare the tags of the IF_ID PC and previous PC address in the cache to determine if they match.
  assign write_tags_match = (IF_ID_PC_curr[15:4] == prediction_ext_prev[13:2]);

  // Update the prediction based on the current state and actual taken value.
  always @(*) begin
      error = 1'b0;                  // Default error state.
      updated_prediction = 14'h0000; // Default predict not taken.
      case (IF_ID_prediction)
          2'h0: begin
            updated_prediction[13:2] = IF_ID_PC_curr[15:4];         // Update the tag.
            updated_prediction[1:0] = (actual_taken) ? 2'h1 : 2'h0; // Strong Not Taken
          end
          2'h1: begin
            updated_prediction[13:2] = IF_ID_PC_curr[15:4];         // Update the tag.
            updated_prediction[1:0] = (write_tags_match) ? ((actual_taken) ? 2'h2 : 2'h0) : 2'h0; // Weak Not Taken; invalidate the entry if write tags do not match.
          end
          2'h2: begin
            updated_prediction[13:2] = IF_ID_PC_curr[15:4];         // Update the tag.
            updated_prediction[1:0] = (write_tags_match) ? ((actual_taken) ? 2'h3 : 2'h1) : 2'h0; // Weak Taken; invalidate the entry if write tags do not match.
          end
          2'h3: begin
            updated_prediction[13:2] = IF_ID_PC_curr[15:4];         // Update the tag.
            updated_prediction[1:0] = (write_tags_match) ? ((actual_taken) ? 2'h3 : 2'h2) : 2'h0; // Strong Taken; invalidate the entry if write tags do not match.
          end
          default: begin
            updated_prediction = 14'h0000; // Default predict not taken.
            error = 1'b1;                  // Invalid prediction state.
          end
      endcase
  end
  /////////////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end
