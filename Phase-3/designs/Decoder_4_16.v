`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////
// Decoder_4_16.v: 4:16 Decoder                  //
//                                               //
// This design takes in a 4-bit signal (`RegId`) //
// and outputs a 16-bit one-hot encoded signal   //
// (`Wordline`), with only one bit high based on //
// the input value.                              //
///////////////////////////////////////////////////
module Decoder_4_16(RegId, Wordline);

  input wire [3:0] RegId;      // 4-bit register ID
  output wire [15:0] Wordline; // 16-bit one hot output

  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  wire [7:0] Wordline_first;  // The first 3:8 decoder output.
  wire [7:0] Wordline_second; // The second 3:8 decoder output.
  /////////////////////////////////////////////

  ////////////////////////////////////////////
  // Implement Decoder as dataflow verilog //
  //////////////////////////////////////////  
  // Instantiate two 3:8 decoders for the lower 3 bits of the RegId enabled on RegId[3].
  Decoder_3_8 iDECODER_first (.RegId(RegId[2:0]), .en(RegId[3]), .Wordline(Wordline_first));
  Decoder_3_8 iDECODER_second (.RegId(RegId[2:0]), .en(~RegId[3]), .Wordline(Wordline_second));

  // Concatenate both outputs.
  assign Wordline = {Wordline_first, Wordline_second};

endmodule

`default_nettype wire // Reset default behavior at the end