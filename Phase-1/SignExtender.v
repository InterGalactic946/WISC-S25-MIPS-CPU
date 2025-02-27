///////////////////////////////////////////////////////
// SignExtender.v                                   //
// This module will take in an input of variable   //
// bit width determined by the parameter and sign //
// extend it                                     //
//////////////////////////////////////////////////
module SignExtender #(
  parameter MSB = 15 // bit number of the MSB (zero indexed)
)(
  input [15:0] in,
  output [15:0] out
);

  ///////////////////////////////////
  // Sign extend input to 16 bits //
  /////////////////////////////////
  assign out = {16{in[MSB]}, in[MSB:0]};

endmodule