`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////
// WriteDecoder_3_8.v: 3:8 Register Write Decoder   //
//                                                  //
// This design takes in a 3-bit register ID and     //
// enables the write operation for a row of bit     //
// cells that make up a WIDTH-bit register.         //
//////////////////////////////////////////////////////
module WriteDecoder_3_8(RegId, WriteReg, Wordline);

  input wire [2:0] RegId;      // 3-bit register ID
  input wire WriteReg;         // write enable signal of a register
  output wire [7:0] Wordline;  // 8-bit register output
  
  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  wire [7:0] Wordline_operand; // Shifted wordline result.
  /////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////
  // Implement WriteDecoder as structural/dataflow verilog //
  //////////////////////////////////////////////////////////
  // Instantiate a 3:8 decoder to get which word of the 8 words to write to.
  Decoder_3_8 iWORD_DECODER (.RegId(RegId), .en(1'b1), .Wordline(Wordline_operand));

  // Wordline is only one hot high if WriteReg is high.
  assign Wordline = (WriteReg) ? Wordline_operand : 8'h00;

endmodule

`default_nettype wire  // Reset default behavior at the end