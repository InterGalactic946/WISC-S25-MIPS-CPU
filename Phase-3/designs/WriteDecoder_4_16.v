`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////
// WriteDecoder_4_16.v: 4:16 Register Write Decoder //
//                                                  //
// This design takes in a 4-bit register ID and     //
// enables the write operation for a row of bit     //
// cells that make up a 16-bit register.            //
//////////////////////////////////////////////////////
module WriteDecoder_4_16(RegId, WriteReg, Wordline);

  input wire [3:0] RegId;      // 4-bit register ID
  input wire WriteReg;         // write enable signal of a register
  output wire [15:0] Wordline; // 16-bit register output
  
  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  wire [15:0] Wordline_operand; // Shifted wordline result.
  /////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////
  // Implement WriteDecoder as structural/dataflow verilog //
  //////////////////////////////////////////////////////////
  // Instantiate a 4-to-16 Decoder for the 4 bit RegId.
  Decoder_4_16 iDECODER_4_16 (.RegId(RegId), .Wordline(Wordline_operand));

  // Wordline is only one hot high if WriteReg is high.
  assign Wordline = (WriteReg) ? Wordline_operand : 16'h0000;

endmodule

`default_nettype wire  // Reset default behavior at the end