`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////////
// addsub_4bit.v: 4-bit Adder/Subtractor Design          //
// This design adds/subtracts two 4-bit vectors         //
// to produce a sum and detects overflow if it occurs. //
////////////////////////////////////////////////////////
module addsub_4bit(Sum, Ovfl, A, B, sub);

  input wire [3:0] A,B;  // two 4-bit input vectors to be added
  input wire sub;	       // add-sub indicator
  output wire [3:0]	Sum; // 4-bit sum output
  output wire Ovfl;      // overflow indicator

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire [3:0] B_operand; // Operand B or its complement.
	wire [3:0] Carries;	  // Driven by .Cout of full_adder_1bit and will in a "promoted" form drive .Cin of full_adder_1bit's.
  ///////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////
  // Implement 4-bit Adder/Subtractor as structural/dataflow verilog //
  ////////////////////////////////////////////////////////////////////
  // Negate B if subtracting.
  assign B_operand = (sub) ? ~B : B; 

  /* Addition/Subtraction computation. */
  full_adder_1bit FA1 [3:0] (.A(A), .B(B_operand), .Cin({Carries[2:0], sub}), .Sum(Sum), .Cout(Carries));
  
  /* Overflow detection */
  assign Ovfl = Carries[3] ^ Carries[2]; // Overflow occurs when the carry into the MSB is not equal to the carry out of the MSB.

endmodule

`default_nettype wire // Reset default behavior at the end