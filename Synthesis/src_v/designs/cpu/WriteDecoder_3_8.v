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
  wire [15:0] Wordline_operand; // Shifted wordline result.
  /////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////
  // Implement WriteDecoder as structural/dataflow verilog //
  //////////////////////////////////////////////////////////
  // Decode the ID by shifting 1 left by RegID amount, only if WriteReg is high otherwise it is zero.
  Shifter iSHIFT (.Shift_In(16'h0001), .Mode(2'h0), .Shift_Val({1'b0, RegId}), .Shift_Out(Wordline_operand));

  // Wordline is only one hot high if WriteReg is high and only the lower 8 bits are used.
  assign Wordline = (WriteReg) ? Wordline_operand[7:0] : 8'h00;

endmodule

`default_nettype wire  // Reset default behavior at the end