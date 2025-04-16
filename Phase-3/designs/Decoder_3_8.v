`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////
// Decoder_3_8.v: 3:8 Decoder                       //
//                                                  //
// This design takes in a 3-bit signal (`RegId`)    //
// and outputs a 8-bit one-hot encoded signal       //
// (`Wordline`), with only one bit high based on    //
// the input value. Typically used for register     //
// selection or enable signal generation.           //
//////////////////////////////////////////////////////
module Decoder_3_8(RegId, Wordline);

  input wire [2:0] RegId;     // 3-bit register ID
  output wire [7:0] Wordline; // 8-bit one hot output

  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  wire [15:0] Wordline_operand; // Shifted wordline result.
  /////////////////////////////////////////////

  //////////////////////////////////////////////////
  // Implement 3:8 Decoder as structural verilog //
  ////////////////////////////////////////////////
  // Instantiate a 4-to-16 Decoder but only care about lower 8 bits.
  Decoder_4_16 iDECODER_4_16 (.RegId({1'b0, RegId}), .Wordline(Wordline_operand));

  // Wordline is one hot and only care about the lower 8 bits from the 4:16 decoder.
  assign Wordline = Wordline_operand[7:0];

endmodule

`default_nettype wire // Reset default behavior at the end