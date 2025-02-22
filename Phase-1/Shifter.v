`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////
// Shifter.v: 16-bit Shifter module                      //  
//                                                       //
// This design takes in a signed 16-bit source and       //
// computes an arithmetic right shift, a logical left    //
// shift, or a rotate right shift                        //
// by a specified shift amount, then outputs the         //
// result.                                               //
///////////////////////////////////////////////////////////
module Shifter (Shift_Out, Shift_In, Shift_Val, Mode);

  input wire [15:0] Shift_In;   // This is the 16-bit input data to perform shift operation on
  input wire [3:0] Shift_Val;   // 4-bit Shift amount (used to shift the input data)
  input wire [1:0] Mode;        // To indicate 0=None, 1=SLL, 2=SRA, 3=ROR
  output wire [15:0] Shift_Out; // 16-bit Shifted output data
  
  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  wire [15:0] Shift_SLL_step, Shift_SRA_step, Shift_ROR_step; // Shifted first stage value for each mode.
  wire [15:0] Shift_SLL_Out, Shift_SRA_Out, Shift_ROR_Out;    // Shifted final stage value for each mode.
  ////////////////////////////////////////////////////////////////////////
  
  ////////////////////////////////////////////
  // Implement Shifter as dataflow verilog //
  //////////////////////////////////////////
  // First 4:1 MUX for SLL shifts Shift_In by 0, 1, 2, 3 bits.
  assign Shift_SLL_step = (Shift_Val[1:0] == 2'h0) ? Shift_In               :
                          (Shift_Val[1:0] == 2'h1) ? {Shift_In[14:0], 1'h0} :
                          (Shift_Val[1:0] == 2'h2) ? {Shift_In[13:0], 2'h0} :
                          (Shift_Val[1:0] == 2'h3) ? {Shift_In[12:0], 3'h0} : Shift_In;
  
  // Second 4:1 MUX for SLL shifts Shift_SLL_step by 0, 2, 8, 12 bits.
  assign Shift_SLL_Out = (Shift_Val[3:2] == 2'h0) ? Shift_SLL_step                 :
                         (Shift_Val[3:2] == 2'h1) ? {Shift_SLL_step[11:0], 4'h0}   :
                         (Shift_Val[3:2] == 2'h2) ? {Shift_SLL_step[7:0], 8'h00}   :
                         (Shift_Val[3:2] == 2'h3) ? {Shift_SLL_step[3:0], 12'h000} : Shift_SLL_step;
  
  // First 4:1 MUX for SRA shifts Shift_In by 0, 1, 2, 3 bits.
  assign Shift_SRA_step = (Shift_Val[1:0] == 2'h0) ? Shift_In                            :
                          (Shift_Val[1:0] == 2'h1) ? {Shift_In[15], Shift_In[15:1]}      :
                          (Shift_Val[1:0] == 2'h2) ? {{2{Shift_In[15]}}, Shift_In[15:2]} :
                          (Shift_Val[1:0] == 2'h3) ? {{3{Shift_In[15]}}, Shift_In[15:3]} : Shift_In;
  
  // Second 4:1 MUX for SRA shifts Shift_SRA_step by 0, 2, 8, 12 bits.
  assign Shift_SRA_Out = (Shift_Val[3:2] == 2'h0) ? Shift_SRA_step                                    :
                         (Shift_Val[3:2] == 2'h1) ? {{4{Shift_SRA_step[15]}}, Shift_SRA_step[15:4]}   :
                         (Shift_Val[3:2] == 2'h2) ? {{8{Shift_SRA_step[15]}}, Shift_SRA_step[15:8]}   :
                         (Shift_Val[3:2] == 2'h3) ? {{12{Shift_SRA_step[15]}}, Shift_SRA_step[15:12]} : Shift_SRA_step;
  
  // First 4:1 MUX for ROR shifts Shift_In by 0, 1, 2, 3 bits.
  assign Shift_ROR_step = (Shift_Val[1:0] == 2'h0) ? Shift_In                        :
                          (Shift_Val[1:0] == 2'h1) ? {Shift_In[0], Shift_In[15:1]}   :
                          (Shift_Val[1:0] == 2'h2) ? {Shift_In[1:0], Shift_In[15:2]} :
                          (Shift_Val[1:0] == 2'h3) ? {Shift_In[2:0], Shift_In[15:3]} : Shift_In;
  
  // Second 4:1 MUX for ROR shifts Shift_ROR_step by 0, 2, 8, 12 bits.
  assign Shift_ROR_Out = (Shift_Val[3:2] == 2'h0) ? Shift_ROR_step                                :
                         (Shift_Val[3:2] == 2'h1) ? {Shift_ROR_step[3:0], Shift_ROR_step[15:4]}   :
                         (Shift_Val[3:2] == 2'h2) ? {Shift_ROR_step[7:0], Shift_ROR_step[15:8]}   :
                         (Shift_Val[3:2] == 2'h3) ? {Shift_ROR_step[11:0], Shift_ROR_step[15:12]} : Shift_ROR_step;

  // The shifted output is one of SLL, SRA, ROR, or none.
  assign Shift_Out = (Mode == 2'h0) ? Shift_In      :
                     (Mode == 2'h1) ? Shift_SLL_Out :
                     (Mode == 2'h2) ? Shift_SRA_Out :
                     (Mode == 2'h3) ? Shift_ROR_Out : Shift_In;

endmodule

`default_nettype wire  // Reset default behavior at the end