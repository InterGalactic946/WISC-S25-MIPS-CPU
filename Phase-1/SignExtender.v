///////////////////////////////////////////////////////
// SignExtender.v                                   //
// This module will take in an input of variable   //
// bit width determined by the parameter and sign //
// extend it                                     //
//////////////////////////////////////////////////
module SignExtender #(
  parameter BIT_WIDTH = 4
)(
  input [BIT_WIDTH - 1:0] in,
  output [15:0] out
);

  ///////////////////////////////////
  // Sign extend input to 16 bits //
  /////////////////////////////////
  assign out = {{(16 - BIT_WIDTH){in[BIT_WIDTH - 1]}}, in};

endmodule