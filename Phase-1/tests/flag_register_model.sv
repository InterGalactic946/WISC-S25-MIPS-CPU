/////////////////////////////////////////////////////////
// flag_register_model.sv                             //
// This module infers a 3-bit register to hold and   //
// change the values of Z, V, and N signals.        //
/////////////////////////////////////////////////////
module flag_register_model (
  input logic clk,          // System clock
  input logic rst,          // active high reset signal
  input logic Z_en, Z_set,  // enable signal and set signal for Z
  input logic V_en, V_set,  // enable signal and set signal for V
  input logic N_en, N_set,  // enable signal and set signal for N
  output logic ZF,          // Z (Zero) signal
  output logic VF,          // V (Overflow) signal
  output logic NF           // N (Sign) signal
);

  ///////////////////////////////////////
  // Flop each singal based on enable //
  /////////////////////////////////////
  always_ff @(posedge clk)
    if (rst)
      ZF <= 1'b0;
    else if (Z_en)
        ZF <= Z_set;
  
  always_ff @(posedge clk)
    if (rst)
      VF <= 1'b0;
    else if (V_en)
      VF <= V_set;

  always_ff @(posedge clk)
    if (rst)
      NF <= 1'b0;
    else if (N_en)
      NF <= N_set;

endmodule