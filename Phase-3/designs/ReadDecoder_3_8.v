`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////
// ReadDecoder_3_8.v: 3:8 Register ID Decoder       //
//                                                  //
// This design takes in a 3-bit register ID and     //
// and enables a read of the row of bit cells that  // 
// make up a WIDTH-bit register.                    //
//////////////////////////////////////////////////////
module ReadDecoder_3_8(RegId, Wordline);

  input wire [2:0] RegId;     // 3-bit register ID
  output wire [7:0] Wordline; // 8-bit register output

  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  wire [15:0] Wordline_operand; // Shifted wordline result.
  /////////////////////////////////////////////////////////

  //////////////////////////////////////////////////
  // Implement ReadDecoder as structural verilog //
  ////////////////////////////////////////////////
  // Decode the ID by shifting 1 left by RegID amount.
  Shifter iSHIFT (.Shift_In(16'h0001), .Mode(2'h0), .Shift_Val({1'b0, RegId}), .Shift_Out(Wordline_operand));

  // Wordline is only one hot high if that register is selected and only the lower 8 bits are used.
  assign Wordline = Wordline_operand[7:0];
	
endmodule

`default_nettype wire // Reset default behavior at the end