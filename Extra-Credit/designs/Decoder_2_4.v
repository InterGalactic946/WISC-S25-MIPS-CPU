`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////
// Decoder_2_4.v: 2:4 Decoder with enable           //
//                                                  //
// This design takes in a 2-bit signal (`RegId`)    //
// and outputs a 4-bit one-hot encoded signal       //
// (`Wordline`), with only one bit high based on    //
// the input value. Typically used for register     //
// selection or enable signal generation.           //
//////////////////////////////////////////////////////
module Decoder_2_4(RegId, en, Wordline);

  input wire [1:0] RegId;      // 2-bit register ID
  input wire en;               // 1-bit enable
  output wire [3:0] Wordline;  // 4-bit one-hot output
  
  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  // wire [3:0] Wordline_operand; // Shifted wordline result.
  // /////////////////////////////////////////////

  // ////////////////////////////////////////////
  // // Implement Decoder as dataflow verilog //
  // //////////////////////////////////////////
  // // Wordline is only one-hot high if that register is selected.
  // assign Wordline_operand = (RegId == 2'h1) ? 4'b0010 : // RegId == 1 -> Wordline[1] high
  //                           (RegId == 2'h2) ? 4'b0100 : // RegId == 2 -> Wordline[2] high
  //                           (RegId == 2'h3) ? 4'b1000 : // RegId == 3 -> Wordline[3] high
  //                           4'b0001; // Default case -> Wordline[0] is high
  
  // // This output is only one hot high if it is enabled.
  // assign Wordline = (en) ? Wordline_operand : 4'h0;

  assign Wordline = en << RegId; // Shift the enable signal to the left by RegId bits to get the one-hot output.

endmodule

`default_nettype wire  // Reset default behavior at the end