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
  wire [15:0] Wordline_operand; // Shifted wordline result.
  /////////////////////////////////////////////

  ////////////////////////////////////////////
  // Implement Decoder as dataflow verilog //
  //////////////////////////////////////////  
  // First 4:1 MUX for SLL shifts 16'h0001 by 0, 1, 2, 3 bits.
  assign Wordline_operand = (RegId[1:0] == 2'h1) ? 16'h0002 :
                            (RegId[1:0] == 2'h2) ? 16'h0004 :
                            (RegId[1:0] == 2'h3) ? 16'h0008: 16'h0001;
  
  // Wordline is only one-hot high if that register is selected.
  assign Wordline = (RegId[3:2] == 2'h1) ? {Wordline_operand[11:0], 4'h0}   :
                    (RegId[3:2] == 2'h2) ? {Wordline_operand[7:0], 8'h00}   :
                    (RegId[3:2] == 2'h3) ? {Wordline_operand[3:0], 12'h000} : Wordline_operand;

	
endmodule

`default_nettype wire // Reset default behavior at the end