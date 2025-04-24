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
  wire [31:0] Wordline_first;  // The first 5:32 decoder output.
  wire [31:0] Wordline_second; // The second 5:32 decoder output.
  /////////////////////////////////////////////

  ////////////////////////////////////////////
  // Implement Decoder as dataflow verilog //
  //////////////////////////////////////////  
  // Instantiate two 5:32 decoders for the lower 5 bits of the RegId enabled on RegId[5].
  Decoder_5_32 iDECODER_first (.RegId(RegId[4:0]), .en(RegId[5]), .Wordline(Wordline_first));
  Decoder_5_32 iDECODER_second (.RegId(RegId[4:0]), .en(~RegId[5]), .Wordline(Wordline_second));

  // Concatenate all outputs.
  assign Wordline = {Wordline_first, Wordline_second};

endmodule

`default_nettype wire  // Reset default behavior at the end