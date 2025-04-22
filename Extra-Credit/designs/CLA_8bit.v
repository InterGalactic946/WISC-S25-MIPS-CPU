`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////////
// CLA_8bit.v: 8-bit Hierarchical Carry Lookahead Adder   //
//                                                        //
// This module implements a 8-bit Carry Lookahead Adder   //
// using two 4-bit CLA blocks. It performs addition or    //
// subtraction based on the `sub` signal and produces     //
// the sum and overflow output for the given 16-bit input.//
// It computes the carry chain and overflow condition     //
// by utilizing the propagate and generate signals from   //
// each 4-bit CLA block.                                  //
////////////////////////////////////////////////////////////
module CLA_8bit(Sum, Cout, Ovfl, pos_Ovfl, neg_Ovfl, A, B, sub);

  input wire [7:0] A,B;                       // 8-bit input bits to be added
  input wire sub;	                            // add-sub indicator
  output wire [7:0] Sum;                      // 8-bit sum output
  output wire Cout, Ovfl, pos_Ovfl, neg_Ovfl; // carry out and overflow indicators

  // /////////////////////////////////////////////////
  // // Declare any internal signals as type wire  //
  // ///////////////////////////////////////////////
  // wire [7:0] B_operand;        // Operand B or its complement.
	// wire [1:0] Carries;	         // Carry chain logic of the 8-bit CLA.
  // wire [1:0] P_group, G_group; // 2-bit propagate and generate signals of each CLA_4bit adder.
  // ///////////////////////////////////////////////

  // /////////////////////////////////////////////////////////
  // // Implement CLA Adder as structural/dataflow verilog //
  // ///////////////////////////////////////////////////////
  // // Negate B if subtracting.
  // assign B_operand = (sub) ? ~B : B;

  // // Form the carry chain based on the group propagate and generates of each 4-bit nibble.
  // assign Carries[0] = G_group[0] | (P_group[0] & sub);
  // assign Carries[1] = G_group[1] | (P_group[1] & G_group[0]) | (P_group[1] & P_group[0] & sub);

  // // Vector instantiate 2 4-bit CLA blocks.
  // CLA_4bit iCLA [1:0] (.A(A),.B(B_operand), .sub(2'h0), .Cin({Carries[0], sub}), .Sum(Sum), .P_group(P_group), .G_group(G_group), .neg_Ovfl(), .pos_Ovfl(), .Ovfl(), .Cout());

  // // Used to know if it is positive overflow.
  // assign pos_Ovfl = ~A[7] & ~B_operand[7] & Sum[7];

  // // Used to know if it is negative overflow.
  // assign neg_Ovfl = A[7] & B_operand[7] & ~Sum[7];

  // // Output the carry out signal.
  // assign Cout = Carries[1];

  // // Overflow when either positive or negative overflow occurs.
  // assign Ovfl = pos_Ovfl | neg_Ovfl;

  assign {Cout, Sum} = A + ((sub) ? -B : B);

  assign pos_Ovfl = ~A[7] & (B[7] == sub) & Sum[7]; // Positive overflow condition
  assign neg_Ovfl = A[7] & (B[7] == ~sub) & ~Sum[7]; // Negative overflow condition

  assign Ovfl = pos_Ovfl | neg_Ovfl; // Overflow when either positive or negative overflow occurs.

endmodule

`default_nettype wire  // Reset default behavior at the end