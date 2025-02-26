`default_nettype none // Set the default as none to avoid implicit net errors

module RED_Unit (Sum, A, B);

  input wire [15:0] A, B;  // 16-bit input operands
  output wire [15:0] Sum;  // 16-bit sum output

  //////////////////////////////////////////////////
  // Declare internal signals as type wire       //
  ////////////////////////////////////////////////
  wire [15:0] sum_level1;  // First-level sum (4-bit chunks)
  wire [3:0] carry_level1; // Carry-out from first-level 4-bit adders

  wire [7:0] sum_level2_aebf, sum_level2_cgdh; // Second-level sum results
  wire [1:0] carry_level2_aebf, carry_level2_cgdh; // Carry-out from second-level adders

  wire [7:0] sum_final; // Third-level sum result
  wire carry_final;     // Carry-out from final addition
  //////////////////////////////////////////////////

  /////////////////////////////////////////////////////////
  // First Level: (4) 4-bit Carry Lookahead Adders (CLAs) //
  /////////////////////////////////////////////////////////
  /********************************************************
   ---------------------------------------------------------------------
   | Level 1: First set of 4-bit CLA adders (initial sum & carry-out)  |
   ---------------------------------------------------------------------
   sum_level1[15:12] = sum_ae   // Sum of A[15:12] + B[15:12]
   sum_level1[11:8]  = sum_bf   // Sum of A[11:8]  + B[11:8]
   sum_level1[7:4]   = sum_cg   // Sum of A[7:4]   + B[7:4]
   sum_level1[3:0]   = sum_dh   // Sum of A[3:0]   + B[3:0]

   carry_level1[3]   = carry_ae // Carry-out from sum_ae
   carry_level1[2]   = carry_bf // Carry-out from sum_bf
   carry_level1[1]   = carry_cg // Carry-out from sum_cg
   carry_level1[0]   = carry_dh // Carry-out from sum_dh
  ********************************************************/ 
  CLA_4bit iCLA_1st [3:0] (
    .A(A), 
    .B(B), 
    .sub(4'h0), 
    .Cin(4'h0), 
    .Sum(sum_level1), 
    .Cout(carry_level1)
  );

  ///////////////////////////////////////////////////////////
  // Second Level: Combine 4-bit sums with additional CLAs //
  ///////////////////////////////////////////////////////////
  /********************************************************************
   ---------------------------------------------------------------------
   | Level 2: Summing adjacent results from Level 1                    |
   ---------------------------------------------------------------------
   sum_level2_aebf[3:0] = sum_aebf_low   // Sum of sum_ae + sum_bf (lower 4 bits)
   sum_level2_aebf[7:4] = sum_aebf_high  // Carry-adjusted sum of sum_ae + sum_bf

   carry_level2_aebf[0] = carry_aebf_low // Carry-out from sum_aebf_low
   carry_level2_aebf[1] = carry_aebf_high // Carry-out from sum_aebf_high

   sum_level2_cgdh[3:0] = sum_cgdh_low  // Sum of sum_cg + sum_dh (lower 4 bits)
   sum_level2_cgdh[7:4] = sum_cgdh_high // Carry-adjusted sum of sum_cg + sum_dh

   carry_level2_cgdh[0] = carry_cgdh_low // Carry-out from sum_cgdh_low
   carry_level2_cgdh[1] = carry_cgdh_high // Carry-out from sum_cgdh_high 
  *********************************************************************/
  // Add sum_ae and sum_bf to form sum_aebf
  CLA_4bit iCLA_2nd_aebf_1 (
    .A(sum_level1[15:12]), 
    .B(sum_level1[11:8]), 
    .sub(1'b0), 
    .Cin(1'b0), 
    .Sum(sum_level2_aebf[3:0]), 
    .Cout(carry_level2_aebf[0])
  );

  // Add propagated carries from sum_ae and sum_bf
  CLA_4bit iCLA_2nd_aebf_2 (
    .A({4{carry_level1[3]}}), 
    .B({4{carry_level1[2]}}), 
    .sub(1'b0), 
    .Cin(carry_level2_aebf[0]), 
    .Sum(sum_level2_aebf[7:4]), 
    .Cout(carry_level2_aebf[1])
  );

  // Add sum_cg and sum_dh to form sum_cgdh
  CLA_4bit iCLA_2nd_cgdh_1 (
    .A(sum_level1[7:4]), 
    .B(sum_level1[3:0]), 
    .sub(1'b0), 
    .Cin(1'b0), 
    .Sum(sum_level2_cgdh[3:0]), 
    .Cout(carry_level2_cgdh[0])
  );

  // Add propagated carries from sum_cg and sum_dh
  CLA_4bit iCLA_2nd_cgdh_2 (
    .A({4{carry_level1[1]}}), 
    .B({4{carry_level1[0]}}), 
    .sub(1'b0), 
    .Cin(carry_level2_cgdh[0]), 
    .Sum(sum_level2_cgdh[7:4]), 
    .Cout(carry_level2_cgdh[1])
  );

  ////////////////////////////////////////////////////
  // Third Level: Final 8-bit Addition             //
  ////////////////////////////////////////////////////
  /*********************************************************
   ---------------------------------------------------------------------
   | Level 3: Final 8-bit addition                                      |
   ---------------------------------------------------------------------
   sum_final[3:0]  = sum_final_low  // Sum of sum_aebf_low + sum_cgdh_low
   sum_final[7:4]  = sum_final_high // Carry-adjusted sum of high-order bits

   carry_final     = carry_final_low // Carry-out from sum_final_low
  **********************************************************/
  // Add sum_aebf and sum_cgdh to form sum_final
  CLA_4bit iCLA_3rd_1 (
    .A(sum_level2_aebf[3:0]), 
    .B(sum_level2_cgdh[3:0]), 
    .sub(1'b0), 
    .Cin(1'b0), 
    .Sum(sum_final[3:0]), 
    .Cout(carry_final)
  );
  
  // Add propagated carries from sum_aebf and sum_cgdh
  CLA_4bit iCLA_3rd_2 (
    .A({{2{sum_level2_aebf[5]}}, sum_level2_aebf[5:4]}), 
    .B({{2{sum_level2_cgdh[6]}}, sum_level2_cgdh[6:4]}), 
    .sub(1'b0), 
    .Cin(carry_final), 
    .Sum(sum_final[7:4]), 
    .Cout()
  );

  // Assign the final sum to the output.
  assign Sum = {{9{sum_final[6]}}, sum_final[6:0]};

endmodule

`default_nettype wire // Reset default behavior at the end
