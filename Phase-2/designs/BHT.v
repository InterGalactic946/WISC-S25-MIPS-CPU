`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////////////
// BHT.v: 16-entry, 2-bit Branch History Table             //
//                                                         //
// This design implements a 16-entry BHT, with each entry  //
// being a 2-bit register. It allows reading and updating  //
// predictions based on the branch PC address.             //
/////////////////////////////////////////////////////////////
module BHT (
    input wire clk,                       // System clock
    input wire rst,                       // active high reset signal
    input wire [3:0] PC_curr_lower,       // 4-bit address (lower 4-bits of current PC from the fetch stage)
    input wire [3:0] IF_ID_PC_curr_lower, // Pipelined 4-bit address (lower 4-bits of previous PC from the fetch stage)
    input wire wen,                       // used to update the BTB register
    input wire actual_taken,              // Actual taken value (from the decode stage)
    output wire predicted_taken           // Predicted 2-bit value (00 => Strong Not Taken, 01 => Weak Not Taken, 10 => Weak Taken, 11 => Strong Taken)
);

  ///////////////////////////////////////////
  // Declare any internal signals as wire  //
  ///////////////////////////////////////////
  wire [15:0] WriteWordline;      // Select lines for 16 registers (write)
  wire [15:0] ReadWordline;       // Select lines for 16 registers (read)
  wire [1:0] unused_bitline;      // Unused bitline read out of the BHT
  reg [1:0] updated_prediction;   // The new prediction to be stored in the BHT on an incorrect prediction
  wire [1:0] prediction;          // The predicted value of the current branch instruction
  reg error;                      // Error flag raised when prediction state is invalid.
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////
  // Implement BHT as structural/dataflow verilog //
  //////////////////////////////////////////////////
  // Instantiate two read register decoders (for both read and write operations).
  ReadDecoder_4_16 iREAD_DECODER (.RegId(PC_curr_lower), .Wordline(ReadWordline));
  WriteDecoder_4_16 iWRITE_DECODER (.RegId(IF_ID_PC_curr_lower), .WriteReg(wen), .Wordline(WriteWordline));

  // Vector instantiate 16 registers, each 2-bit wide for the BHT (reading from the same register out of both bitlines).
  Register #(.WIDTH(2)) iRF_BHT [15:0] (.clk({16{clk}}), .rst({16{rst}}), .D(updated_prediction), .WriteReg(WriteWordline), .ReadEnable1(ReadWordline), .ReadEnable2(ReadWordline), .Bitline1(prediction), .Bitline2(unused_bitline));

  // Output the prediction as the MSB of the 2-bit predictor.
  assign predicted_taken = prediction[1];
  ///////////////////////////////////////////////////

  //////////////////////////////////////////////////////
  // Update the prediction based on the current state //
  //////////////////////////////////////////////////////
  always @(*) begin
      error = 1'b0;              // Default error state.
      updated_prediction = 2'h0; // Default predict not taken.
      case (prediction)
          2'h0: updated_prediction = (actual_taken) ? 2'h1 : 2'h0; // Strong Not Taken
          2'h1: updated_prediction = (actual_taken) ? 2'h2 : 2'h1; // Weak Not Taken
          2'h2: updated_prediction = (actual_taken) ? 2'h3 : 2'h2; // Weak Taken
          2'h3: updated_prediction = (actual_taken) ? 2'h3 : 2'h2; // Strong Taken
          default: begin
            updated_prediction = 2'h0; // Default predict not taken.
            error = 1'b1;              // Invalid prediction state
          end
      endcase
  end
 ////////////////////////////////////////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end
