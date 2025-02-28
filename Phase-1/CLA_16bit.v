`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////////
// CLA_16bit.v: 16-bit Hierarchical Carry Lookahead Adder //
//                                                        //
// This module implements a 16-bit Carry Lookahead Adder  //
// using four 4-bit CLA blocks. It performs addition or   //
// subtraction based on the `sub` signal and produces     //
// the sum and overflow output for the given 16-bit input.//
// It computes the carry chain and overflow condition     //
// by utilizing the propagate and generate signals from   //
// each 4-bit CLA block.                                  //
////////////////////////////////////////////////////////////
module CLA_16bit(Sum, Cout, Ovfl, pos_Ovfl, neg_Ovfl, A, B, sub);

  input wire [15:0] A,B;                      // 16-bit input bits to be added
  input wire sub;	                            // add-sub indicator
  output wire [15:0] Sum;                     // 16-bit sum output that will be saturated
  output wire Cout, Ovfl, pos_Ovfl, neg_Ovfl; // carry out and overflow indicators

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire [15:0] B_operand;       // Operand B or its complement.
	wire [3:0] Carries;	         // Carry chain logic of the 16-bit CLA.
  wire [15:0] Sum_step;        // Step sum result.
  wire [3:0] P_group, G_group; // 4-bit propagate and generate signals of each CLA_4bit adder.
  ///////////////////////////////////////////////

  /////////////////////////////////////////////////////////
  // Implement CLA Adder as structural/dataflow verilog //
  ///////////////////////////////////////////////////////
  // Negate B if subtracting.
  assign B_operand = (sub) ? ~B : B;

  // Form the carry chain based on the group propagate and generates of each 4-bit nibble.
  assign Carries[0] = G_group[0] | (P_group[0] & sub);
  assign Carries[1] = G_group[1] | (P_group[1] & G_group[0]) | (P_group[1] & P_group[0] & sub);
  assign Carries[2] = G_group[2] | (P_group[2] & G_group[1]) | (P_group[2] & P_group[1] & G_group[0]) | (P_group[2] & P_group[1] & P_group[0] & sub);
  assign Carries[3] = G_group[3] | (P_group[3] & G_group[2]) | (P_group[3] & P_group[2] & G_group[1]) | (P_group[3] & P_group[2] & P_group[1] & G_group[0]) | (P_group[3] & P_group[2] & P_group[1] & P_group[0] & sub);

  // Vector instantiate 4 4-bit CLA blocks.
  CLA_4bit iCLA [3:0] (.A(A),.B(B_operand), .sub(4'h0), .Cin({Carries[2:0], sub}), .Sum(Sum_step), .P_group(P_group), .G_group(G_group), .neg_Ovfl(), .pos_Ovfl(), .Ovfl(), .Cout());

  // Used to know if it is positive overflow.
  assign pos_Ovfl = ~A[15] & ~B_operand[15] & Sum_step[15];

  // Used to know if it is negative overflow.
  assign neg_Ovfl = A[15] & B_operand[15] & ~Sum_step[15];

  // Output the carry out signal.
  assign Cout = Carries[3];

  // Overflow when either positive or negative overflow occurs.
  assign Ovfl = pos_Ovfl | neg_Ovfl;

  // Saturate result based on overflow condition.
  assign Sum = (pos_Ovfl) ? 16'h7FFF : 
               (neg_Ovfl) ? 16'h8000 : Sum_step;

endmodule

`default_nettype wire  // Reset default behavior at the end