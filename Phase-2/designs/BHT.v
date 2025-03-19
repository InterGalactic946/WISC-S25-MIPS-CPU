`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////////////
// BHT.v: 16-entry, 2-bit Branch History Table             //
//                                                         //
// This design implements a 16-entry BHT, with each entry  //
// being a 2-bit register. It allows reading and updating  //
// predictions based on the branch PC address.             //
/////////////////////////////////////////////////////////////
module BHT (
    input wire clk,                    // System clock
    input wire rst,                    // active high reset signal
    input wire [3:0] PC_curr,          // 4-bit address (lower 4-bits of current PC from the fetch stage)
    input wire [3:0] IF_ID_PC_curr,    // Pipelined 4-bit address (lower 4-bits of previous PC from the fetch stage)
    input wire [1:0] IF_ID_prediction, // The predicted value of the previous branch instruction
    input wire wen,                    // used to update the BTB memory on a misprediction
    input wire enable,                 // Enable signal for the BHT
    input wire actual_taken,           // Actual taken value (from the decode stage)
    
    output wire [1:0] prediction      // The 2-bit predicted value of the current branch instruction.
  );

  ///////////////////////////////////////////
  // Declare any internal signals as wire  //
  ///////////////////////////////////////////
  reg [15:0] updated_prediction;  // The new prediction to be stored in the BHT on an incorrect prediction.
  wire [15:0] prediction_ext;     // The 16-bit predicted value of the current branch instruction, of which we only use lower 2-bits.
  wire [3:0] addr;                // Used to determine read vs write address.
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
  ///////////////////////////////////////////////////

  //////////////////////////////////////////////////////
  // Update the prediction based on the current state //
  //////////////////////////////////////////////////////
  always @(*) begin
      error = 1'b0;                  // Default error state.
      updated_prediction = 16'h0000; // Default predict not taken.
      case (IF_ID_prediction)
          2'h0: updated_prediction = (actual_taken) ? 16'h0001 : 16'h0000; // Strong Not Taken
          2'h1: updated_prediction = (actual_taken) ? 16'h0002 : 16'h0001; // Weak Not Taken
          2'h2: updated_prediction = (actual_taken) ? 16'h0003 : 16'h0002; // Weak Taken
          2'h3: updated_prediction = (actual_taken) ? 16'h0003 : 16'h0002; // Strong Taken
          default: begin
            updated_prediction = 16'h0000; // Default predict not taken.
            error = 1'b1;                  // Invalid prediction state.
          end
      endcase
  end
 /////////////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end
