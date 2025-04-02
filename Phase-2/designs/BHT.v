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
  reg [15:0] updated_prediction;  // The new prediction to be stored in the BHT on an incorrect prediction.
  wire [15:0] prediction_ext;     // The 16-bit predicted value of the current branch instruction, of which we only use lower 2-bits.
  wire [3:0] addr;                // Used to determine read vs write address.
  wire tags_match;                // Used to determine if the current PC tag matches the previous PC tag cached in BHT.
  reg error;                      // Error flag raised when prediction state is invalid.
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////
  // Implement BHT as structural/dataflow verilog //
  //////////////////////////////////////////////////
  // Our read address is PC_curr while our write address is IF_ID_PC_curr.
  assign addr = (wen) ? IF_ID_PC_curr : PC_curr;

  // Infer the branch history table as an asynchronously read, synchronously written memory, enabled when not stalling.
  memory1c #(4) iMEM_BHT (.data_out(prediction_ext),
                          .data_in(updated_prediction),
                          .addr(addr),
                          .enable(enable),
                          .data(1'b1),
                          .wr(wen),
                          .clk(clk),
                          .rst(rst)
                          );
  
  // Output the current prediction as the lower 2 bits of the prediction_ext.
  assign prediction = prediction_ext[1:0];

  // Compare the tags of the current PC and previous PC address in the cache to determine if they match.
  assign tags_match = (PC_curr[15:4] == prediction_ext[13:2]);

  // If the tags match, use the prediction; otherwise, assume not taken.
  assign taken = (tags_match) ? prediction_ext[1] : 1'b0; 
  ///////////////////////////////////////////////////

  //////////////////////////////////////////////////////
  // Update the prediction based on the current state //
  //////////////////////////////////////////////////////
  always @(*) begin
      error = 1'b0;                  // Default error state.
      updated_prediction = 16'h0000; // Default predict not taken.
      case (IF_ID_prediction)
          2'h0: begin
            updated_prediction[15:14] = 2'h0;                       // Default upper bits.
            updated_prediction[13:2] = IF_ID_PC_curr[15:4];         // Update the tag.
            updated_prediction[1:0] = (actual_taken) ? 2'h1 : 2'h0; // Strong Not Taken
          end
          2'h1: begin
            updated_prediction[15:14] = 2'h0;                       // Default upper bits.
            updated_prediction[13:2] = IF_ID_PC_curr[15:4];         // Update the tag.
            updated_prediction[1:0] = (actual_taken) ? 2'h2 : 2'h1; // Weak Not Taken
          end
          2'h2: begin
            updated_prediction[15:14] = 2'h0;                       // Default upper bits.
            updated_prediction[13:2] = IF_ID_PC_curr[15:4];         // Update the tag.
            updated_prediction[1:0] = (actual_taken) ? 2'h3 : 2'h2; // Weak Taken
          end
          2'h3: begin
            updated_prediction[15:14] = 2'h0;                       // Default upper bits.
            updated_prediction[13:2] = IF_ID_PC_curr[15:4];         // Update the tag.
            updated_prediction[1:0] = (actual_taken) ? 2'h3 : 2'h2; // Strong Taken
          end
          default: begin
            updated_prediction = 16'h0000; // Default predict not taken.
            error = 1'b1;                  // Invalid prediction state.
          end
      endcase
  end
  /////////////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end
