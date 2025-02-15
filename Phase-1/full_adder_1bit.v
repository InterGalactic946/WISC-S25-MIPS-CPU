`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////
// full_adder_1bit.v: 1-bit Full Adder Design     //
// This design takes in 3 bits                   //
// and adds them to produce a sum and carry out //
/////////////////////////////////////////////////
module full_adder_1bit (Sum, Cout, A, B, Cin);

  input wire A,B,Cin;    // three 1-bit input bits to be added
  output wire Sum, Cout; // 1-bit sum output and carry out

  ///////////////////////////////////////////////
  // Implement Full Adder as dataflow verilog //
  /////////////////////////////////////////////
  // Form the sum of the full adder.
  assign Sum = A ^ B ^ Cin;

  // Form the carry out of the full adder.
  assign Cout = (A & B) | (Cin & (A ^ B)); 
	
endmodule

`default_nettype wire // Reset default behavior at the end