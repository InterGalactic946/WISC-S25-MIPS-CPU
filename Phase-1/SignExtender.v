`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////
// SignExtender.v                                   //
// This module will take in an input of variable   //
// bit width determined by the parameter and sign //
// extend it                                     //
//////////////////////////////////////////////////
module SignExtender (input wire [15:0] signed_in, output wire [15:0] signed_out);

  parameter MSB = 15 // bit number of the MSB (zero indexed)

  ///////////////////////////////////
  // Sign extend input to 16 bits //
  /////////////////////////////////
  assign signed_out = {16{in[MSB]}, signed_in[MSB:0]};

endmodule

`default_nettype wire  // Reset default behavior at the end