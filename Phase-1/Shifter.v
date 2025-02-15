`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////
// Shifter.v: 16-bit Shifter module                      //  
//                                                       //
// This design takes in a signed 16-bit source and       //
// computes an arithmetic right shift or a logical left  //
// shift by a specified shift amount, then outputs the   //
// result.                                               //
///////////////////////////////////////////////////////////
module Shifter (Shift_Out, Shift_In, Shift_Val, Mode);

  input wire [15:0] Shift_In;   // This is the 16-bit input data to perform shift operation on
  input wire [3:0] Shift_Val;   // 4-bit Shift amount (used to shift the input data)
  input wire Mode;              // To indicate 0=SLL or 1=SRA
  output wire [15:0] Shift_Out; // 16-bit Shifted output data
  
  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  wire [15:0] shft_stg1; // Shifted value by 1 bit or kept original.
  wire [15:0] shft_stg2; // Shifted value by 2 bits or kept previous.
  wire [15:0] shft_stg3; // Shifted value by 4 bits or kept previous.
  ////////////////////////////////////////////////////////////////////
  
  ////////////////////////////////////////////
  // Implement Shifter as dataflow verilog //
  //////////////////////////////////////////
  // If bit-0 of the shift amount is high we shift the input vector right or left by 1-bit based on the mode, otherwise, we keep the original input.
  assign shft_stg1 = (Shift_Val[0]) ? ((Mode) ? {Shift_In[15], Shift_In[15:1]} : {Shift_In[14:0], 1'h0}) : (Shift_In);
    
  // If bit-1 of the shift amount is high we shift the input vector right or left by 2-bits based on the mode, otherwise, we keep the first stage.
  assign shft_stg2 = (Shift_Val[1]) ? ((Mode) ? {{2{shft_stg1[15]}}, shft_stg1[15:2]} : {shft_stg1[13:0], 2'h0}) : (shft_stg1);

  // If bit-2 of the shift amount is high we shift the input vector right or left by 4-bits based on the mode, otherwise, we keep the second stage.
  assign shft_stg3 = (Shift_Val[2]) ? ((Mode) ? {{4{shft_stg2[15]}}, shft_stg2[15:4]} : {shft_stg2[11:0], 4'h0}) : (shft_stg2);

  // If bit-3 of the shift amount is high we shift the input vector right or left by 8-bits based on the mode, otherwise, we keep the third stage.
  assign Shift_Out = (Shift_Val[3]) ? ((Mode) ? {{8{shft_stg3[15]}}, shft_stg3[15:8]} : {shft_stg3[7:0], 8'h00}) : (shft_stg3);
	
endmodule

`default_nettype wire  // Reset default behavior at the end