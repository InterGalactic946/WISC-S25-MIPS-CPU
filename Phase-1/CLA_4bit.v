`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////////
// CLA_4bit.v: 4-bit Carry Lookahead Adder                //
//                                                        //
// This module implements a 4-bit Carry Lookahead Adder   //
// with the ability to add or subtract two 4-bit inputs.  //
// It generates the sum and overflow indicator for the    //
// given inputs. The module also computes the propagate   //
// and generate signals for use in higher-level carry     //
// lookahead adders.                                      //
////////////////////////////////////////////////////////////
module CLA_4bit(Sum, Ovfl, P_group, G_group, A, B, Cin, sub);

  input wire [3:0] A,B;         // 4-bit input bits to be added
  input wire sub;	              // add-sub indicator
  input wire Cin;	              // carry-in to the CLA
  output wire [3:0]	Sum;        // 4-bit sum output
  output wire Ovfl;             // overflow indicator
  output wire P_group, G_group; // group propagate and generate signals

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire [3:0] B_operand;     // Operand B or its complement.
  wire Cin_operand;         // Carry in modified to the CLA.
  wire Ovfl_sub, Ovfl_add;  // overflow indicator based on sub or add
  wire [3:0] C, P, G;       // 4-bit carry, propagate and generate signals of 4-bit nibble.
  ///////////////////////////////////////////////

  ///////////////////////////////////////////////////
  // Implement CLA_4bit Adder as dataflow verilog //
  /////////////////////////////////////////////////
  // Negate B if subtracting.
  assign B_operand = (sub) ? ~B : B; 

  // Make Cin as 1'b1 when subtracting.
  assign Cin_operand = (sub) ? 1'b1 : Cin;

  // Form the propagate signal of the operation.
  assign P = A | B_operand;

  // Form the generate signal of the operation.
  assign G = A & B_operand;

  // Form the carry chain logic
  assign C[0] = G[0] | (P[0] & Cin_operand);
  assign C[1] = G[1] | (P[1] & G[0]) | (P[1] & P[0] & Cin_operand);
  assign C[2] = G[2] | (P[2] & G[1]) | (P[2] & P[1] & G[0]) | (P[2] & P[1] & P[0] & Cin_operand);
  assign C[3] = G[3] | (P[3] & G[2]) | (P[3] & P[2] & G[1]) | (P[3] & P[2] & P[1] & G[0]) | (P[3] & P[2] & P[1] & P[0] & Cin_operand);

  // Form the sum of the CLA adder.
  assign Sum[0] = A[0] ^ B_operand[0] ^ Cin_operand;
  assign Sum[1] = A[1] ^ B_operand[1] ^ C[0];
  assign Sum[2] = A[2] ^ B_operand[2] ^ C[1];
  assign Sum[3] = A[3] ^ B_operand[3] ^ C[2];

  /* Overflow Detection */
    /* 1) Addition:
        When both operands have the same sign and the result has a different sign.
    */
    /* 2) Subtraction:
        a) A is positive and B is negative but the result is negative.
        b) A is negative and B is positive but the result is positive.
    */
  */
  assign Ovfl_sub = (~A[3] & B_operand[3] & Sum[3]) | (A[3] & ~B_operand[3] & ~Sum[3]);
  assign Ovfl_add = (A[3] & B_operand[3] & ~Sum[3]) | (~A[3] & ~B_operand[3] & Sum[3]);
  assign Ovfl = (sub) ? Ovfl_sub : Ovfl_add;

  // Get the group's propagate signal as a whole.
  assign P_group = &P;

  // Get the group's generate signal as a whole.
  assign G_group = G[3] | (P[3] & G[2]) | (P[3] & P[2] & G[1]) | (P[3] & P[2] & P[1] & G[0]);

endmodule

`default_nettype wire  // Reset default behavior at the end