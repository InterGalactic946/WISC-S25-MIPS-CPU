`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////
// Decoder_5_32.v: 5:32 Decoder with enable      //
//                                               //
// This design takes in a 5-bit signal (`RegId`) //
// and outputs a 32-bit one-hot encoded signal   //
// (`Wordline`), with only one bit high based on //
// the input value.                              //
///////////////////////////////////////////////////
module Decoder_5_32(RegId, en, Wordline);

  input wire [4:0] RegId;      // 4-bit register ID
  input wire en;               // 1-bit enable
  output wire [31:0] Wordline; // 16-bit one hot output

  // ////////////////////////////////////////////////
  // // Declare any internal signals as type wire //
  // //////////////////////////////////////////////
  // wire [15:0] Wordline_first;  // The first 4:16 decoder output.
  // wire [15:0] Wordline_second; // The second 4:16 decoder output.
  // /////////////////////////////////////////////

  // ////////////////////////////////////////////
  // // Implement Decoder as dataflow verilog //
  // //////////////////////////////////////////  
  // // Instantiate two 4:16 decoders for the lower 4 bits of the RegId enabled on RegId[4].
  // Decoder_4_16 iDECODER_first (.RegId(RegId[3:0]), .en(RegId[4]), .Wordline(Wordline_first));
  // Decoder_4_16 iDECODER_second (.RegId(RegId[3:0]), .en(~RegId[4]), .Wordline(Wordline_second));

  // // Concatenate both outputs and only output it if enabled, else 0.
  // assign Wordline = (en) ? {Wordline_first, Wordline_second} : 32'h00000000;

  assign Wordline = en << RegId;

endmodule

`default_nettype wire // Reset default behavior at the end