`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////
// PSA_16bit.v: 16-bit Parallel Signed Adder (PSA)       //  
//                                                       //
// This module performs four half-byte signed additions  //
// in parallel to achieve sub-word parallelism.          //
// Specifically, each of the four half-bytes (4 bits)    //
// is treated as a separate signed number while being    //
// stored as a single 16-bit vector.                     //
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
  wire [3:0] Overflow; // Overflow for each 4-bit nibble.
  ///////////////////////////////////////////////////////
  
  //////////////////////////////////////////////
  // Implement PSA_16bit as dataflow verilog //
  ////////////////////////////////////////////
  // Vector instantiate 4 4-bit adder blocks for the PSA_16bit.                      
  addsub_4bit iAddSub [3:0] (.A({A[15:12], A[11:8], A[7:4], A[3:0]}), 
                             .B({B[15:12], B[11:8], B[7:4], B[3:0]}), .sub(4'h0), 
                             .Sum({Sum[15:12], Sum[11:8], Sum[7:4], Sum[3:0]}), 
                             .Ovfl(Overflow)
                            );

  // The 'Error' flag is set when any of the individual nibble sums result in overflow.
  assign Error = |Overflow;

endmodule

`default_nettype wire  // Reset default behavior at the end