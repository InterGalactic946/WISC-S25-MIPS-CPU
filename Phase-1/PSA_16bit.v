`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////
// PSA_16bit.v: 16-bit Parallel Signed Adder (PSA)       //  
//                                                       //
// This module performs four half-byte signed additions  //
// in parallel to achieve sub-word parallelism.          //
// Specifically, each of the four half-bytes (4 bits)    //
// is treated as a separate signed number while being    //
// stored as 4 saturated 4-bit vectors.                  //
//                                                       //
// When PSA is executed, these four numbers are added    //
// separately while maintaining their sub-word integrity.//
///////////////////////////////////////////////////////////
module PSA_16bit (Sum, Error, A, B);

  input wire [15:0] A, B; // Input data values
  output wire [15:0] Sum; // Sum output
  output wire Error; 	    // To indicate overflows
  
  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  wire [3:0] overflows, pos_Ovfl, neg_Ovfl; // Overflows for each 4-bit nibble.
  wire [15:0] Sum_operand; // Stores each 4-bit nibble's sum..
  ///////////////////////////////////////////////////////
  
  //////////////////////////////////////////////
  // Implement PSA_16bit as dataflow verilog //
  ////////////////////////////////////////////
  // Vector instantiate 4 4-bit CLA adder blocks for the PSA_16bit.                      
  CLA_4bit iCLA [3:0] (.A(A),.B(B), .sub(4'h0), .Cin(4'h0), .Sum(Sum_operand), .Ovfl(overflows), .pos_Ovfl(pos_Ovfl), .neg_Ovfl(neg_Ovfl), .P_group(), .G_group());

  // Saturate to the most positve/negative number in 4-bits based on the overflow condition.
  assign Sum[3:0]   = (pos_Ovfl[0]) ? 4'h7 : 
                      (neg_Ovfl[0]) ? 4'h8 : Sum_operand[3:0];
  assign Sum[7:4]   = (pos_Ovfl[1]) ? 4'h7 : 
                      (neg_Ovfl[1]) ? 4'h8 : Sum_operand[7:4];
  assign Sum[11:8]  = (pos_Ovfl[2]) ? 4'h7 : 
                      (neg_Ovfl[2]) ? 4'h8 : Sum_operand[11:8];
  assign Sum[15:12] = (pos_Ovfl[3]) ? 4'h7 : 
                      (neg_Ovfl[3]) ? 4'h8 : Sum_operand[15:12];
  
  // The 'Error' flag is set when any of the individual nibble sums result in overflow.
  assign Error = |overflows;

endmodule

`default_nettype wire  // Reset default behavior at the end