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
  // wire [3:0] Wordline_2_4;     // The wordline of the 2:4 decoder.
  // wire [15:0] Wordline_first;  // The first 4:16 decoder output.
  // wire [15:0] Wordline_second; // The second 4:16 decoder output.
  // wire [15:0] Wordline_third;  // The third 4:16 decoder output.
  // wire [15:0] Wordline_fourth; // The fourth 4:16 decoder output.
  // /////////////////////////////////////////////
  // // Instantiate a 2:4 decoder using the upper 2 bits of RegId.
  // Decoder_2_4 iDECODER_2_4 (.RegId(RegId[5:4]), .en(1'b1), .Wordline(Wordline_2_4));

  // // Instantiate 4 4-to-16 Decoders for the lower 4 bits, enabled from the one-hot 2:4 decoder output.
  // Decoder_4_16 iDECODER_first (.RegId(RegId[3:0]), .en(Wordline_2_4[0]), .Wordline(Wordline_first));
  // Decoder_4_16 iDECODER_second (.RegId(RegId[3:0]), .en(Wordline_2_4[1]), .Wordline(Wordline_second));
  // Decoder_4_16 iDECODER_third (.RegId(RegId[3:0]), .en(Wordline_2_4[2]), .Wordline(Wordline_third));
  // Decoder_4_16 iDECODER_fourth (.RegId(RegId[3:0]), .en(Wordline_2_4[3]), .Wordline(Wordline_fourth));

  // // Concatenate all outputs.
  // assign Wordline = {Wordline_first, Wordline_second, Wordline_third, Wordline_fourth};

  assign Wordline = 1'b1 << RegId; // Shift the enable signal to the left by RegId bits to get the one-hot output.

endmodule

`default_nettype wire  // Reset default behavior at the end