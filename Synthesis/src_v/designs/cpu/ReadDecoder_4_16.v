`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////
// ReadDecoder_4_16.v: 4:16 Register ID Decoder  //
//                                               //
// This design takes in a 4 bit register ID      //
// and enables a read of the row of bit cells    //
// that make up a 16-bit register.               //
///////////////////////////////////////////////////
module ReadDecoder_4_16(RegId, Wordline);

  input wire [3:0] RegId;      // 4-bit register ID
  output wire [15:0] Wordline; // 16-bit register output

  //////////////////////////////////////////////////
  // Implement ReadDecoder as structural verilog //
  ////////////////////////////////////////////////
  // Decode the ID by shifting 1 left by RegID amount.
  Shifter iSHIFT (.Shift_In(16'h0001), .Mode(2'h0), .Shift_Val(RegId), .Shift_Out(Wordline));
	
endmodule

`default_nettype wire // Reset default behavior at the end