`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////
// Decoder_6_64.v: 6:64 Decoder                     //
//                                                  //
// This design takes in a 6-bit signal (`RegId`)    //
// and outputs a 64-bit one-hot encoded signal      //
// (`Wordline`), with only one bit high based on    //
// the input value.                                 //
//////////////////////////////////////////////////////
module Decoder_6_64(RegId, Wordline);

  input wire [5:0] RegId;      // 6-bit register ID
  output wire [63:0] Wordline; // 64-bit one-hot output
  
  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  wire [15:0] Wordline_operand; // Output of the 4-to-16 decoder.
  ////////////////////////////////////////////
  // Instantiate a 4-to-16 Decoder for the lower 4 bits.
  Decoder_4_16 iDECODER_4_16 (.RegId(RegId[3:0]), .Wordline(Wordline_operand));

  // Shift the lower level decoded value based on the upper 2 bits. (Essentially saying take the output from the 4:16 decoder and shift it by 16*RegId[5:4] bits
  assign Wordline = (RegId[5:4] == 2'h1) ? {32'h00000000, Wordline_operand, 16'h0000} :
                    (RegId[5:4] == 2'h2) ? {16'h0000, Wordline_operand, 32'h00000000} :
                    (RegId[5:4] == 2'h3) ? {Wordline_operand, 48'h000000000000} : {48'h000000000000, Wordline_operand};

endmodule

`default_nettype wire  // Reset default behavior at the end