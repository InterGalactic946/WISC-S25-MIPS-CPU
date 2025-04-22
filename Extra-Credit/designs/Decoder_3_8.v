`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////
// Decoder_3_8.v: 3:8 Decoder with enable           //
//                                                  //
// This design takes in a 3-bit signal (`RegId`)    //
// and outputs a 8-bit one-hot encoded signal       //
// (`Wordline`), with only one bit high based on    //
// the input value. Typically used for register     //
// selection or enable signal generation.           //
//////////////////////////////////////////////////////
module Decoder_3_8(RegId, en, Wordline);

  input wire [2:0] RegId;     // 3-bit register ID
  input wire en;              // 1-bit enable
  output wire [7:0] Wordline; // 8-bit one hot output

  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  // wire [3:0] Wordline_first;  // The first 2:4 decoder output.
  // wire [3:0] Wordline_second; // The second 2:4 decoder output.
  // /////////////////////////////////////////////

  // //////////////////////////////////////////////////
  // // Implement 3:8 Decoder as structural verilog //
  // ////////////////////////////////////////////////
  // // Instantiate two 2:4 decoders using the lower 2 bits of RegId, and MSB dictating the enable.
  // Decoder_2_4 iDECODER_first (.RegId(RegId[1:0]), .en(RegId[2]), .Wordline(Wordline_first));
  // Decoder_2_4 iDECODER_second (.RegId(RegId[1:0]), .en(~RegId[2]), .Wordline(Wordline_second));

  // // Concatenate both outputs and only output it if enabled, else 0.
  // assign Wordline = (en) ? {Wordline_first, Wordline_second} : 8'h00;

  assign Wordline = en << RegId; // Shift the enable signal to the left by RegId bits to get the one-hot output.

endmodule

`default_nettype wire // Reset default behavior at the end