`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////////
// RED_Unit.v: Reduction Unit                             //
//                                                        //
// This module implements a 16-bit adder using a tree of  //
// 4-bit Carry Lookahead Adders (CLAs). The addition is   //
// performed in multiple stages. At the first level,      //
// four 4-bit adders are used to generate 5-bit results   //
// for each pair of 4-bit operands:                       //
//   - sum_ae = aaaa + eeee                               //
//   - sum_bf = bbbb + ffff                               //
//   - sum_cg = cccc + gggg                               //
//   - sum_dh = dddd + hhhh                               //
// At the second level, the partial sums are added:       //
//   - sum_aebf = sum_ae + sum_bf (5-bit + 5-bit)         //
//   - sum_cgdh = sum_cg + sum_dh (5-bit + 5-bit)         //
// Finally, the third level adds the results from the     //
// second level to generate the final 16-bit sum.         //
////////////////////////////////////////////////////////////
module RED_Unit (Sum, A, B);

  input wire [15:0] A, B;  // 16-bit input operands
  output wire [15:0] Sum;  // 16-bit sum output

  ////////////////////////////////////////////
  // Declare internal signals as type wire //
  //////////////////////////////////////////
  //wire [3:0] sum_ae, sum_bf, sum_cg, sum_dh; // First-level sums (4-bit chunks).
  //wire carry_ae, carry_bf, carry_cg, carry_dh; // Carry-outs from first-level 4-bit adders.
  //wire ov_ae, ov_bf, ov_cg, ov_dh; // overflow indicators from first-level 4-bit adders.
  //wire [7:0] input_ae, input_bf, input_cg, input_dh; // Inputs to the second level, i.e., the 8-bit CLAs.
  //wire [7:0] sum_aebf, sum_cgdh; // Second-level 8-bit sum results.
  //wire [7:0] sum_final; // Third-level sum result.
  //////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////
  // First Level: (4) 4-bit Carry Lookahead Adders (CLAs) //
  /////////////////////////////////////////////////////////
  // Get the sum of aaaa + eeee in sum_ae and the carry out as carry_ae, along with the ov_ae overflow indicator.
  //CLA_4bit iCLA_first_level_1 (.A(A[15:12]), .B(B[15:12]), .sub(1'b0), .Cin(1'b0), .Sum(sum_ae), .Cout(carry_ae), .Ovfl(ov_ae));
  
  // Get the sum of bbbb + ffff in sum_bf and the carry out as carry_bf, along with the ov_bf overflow indicator.
  //CLA_4bit iCLA_first_level_2 (.A(A[11:8]), .B(B[11:8]), .sub(1'b0), .Cin(1'b0), .Sum(sum_bf), .Cout(carry_bf), .Ovfl(ov_bf));
  
  // Get the sum of cccc + gggg in sum_cg and the carry out as carry_cg, along with the ov_cg overflow indicator.
  //CLA_4bit iCLA_first_level_3 (.A(A[7:4]), .B(B[7:4]), .sub(1'b0), .Cin(1'b0), .Sum(sum_cg), .Cout(carry_cg), .Ovfl(ov_cg));
  
  // Get the sum of dddd + hhhh in sum_dh and the carry out as carry_dh, along with the ov_dh overflow indicator.
  //CLA_4bit iCLA_first_level_4 (.A(A[3:0]), .B(B[3:0]), .sub(1'b0), .Cin(1'b0), .Sum(sum_dh), .Cout(carry_dh), .Ovfl(ov_dh));

  // Get the ae input operand to the second level.
  //assign input_ae = (ov_ae) ? {{4{carry_ae}}, sum_ae} : {{4{sum_ae[3]}}, sum_ae};
  
  // Get the bf input operand to the second level.
  //assign input_bf = (ov_bf) ? {{4{carry_bf}}, sum_bf} : {{4{sum_bf[3]}}, sum_bf};

  // Get the cg input operand to the second level.
  //assign input_cg = (ov_cg) ? {{4{carry_cg}}, sum_cg} : {{4{sum_cg[3]}}, sum_cg};

  // Get the dh input operand to the second level.
  //assign input_dh = (ov_dh) ? {{4{carry_dh}}, sum_dh} : {{4{sum_dh[3]}}, sum_dh};
  
  ////////////////////////////////////////////////////////////////////////
  // Second Level: Use (2) 8-bit CLAs to compute sum_aebf and sum cgdh //
  //////////////////////////////////////////////////////////////////////
  // Get the sum of input_ae + input_bf in sum_aebf.
  //CLA_8bit iCLA_second_level_1 (.A(input_ae), .B(input_bf), .sub(1'b0), .Sum(sum_aebf));

  // Get the sum of input_cg + input_dh in sum_cgdh.
  //CLA_8bit iCLA_second_level_2 (.A(input_cg), .B(input_dh), .sub(1'b0), .Sum(sum_cgdh));

  ////////////////////////////////////////
  // Third Level: Final 8-bit Addition //
  //////////////////////////////////////
  // Get the sum of sum_aebf + sum_cgdh in sum_final.
  //CLA_8bit iCLA_third_level (.A(sum_aebf), .B(sum_cgdh), .sub(1'b0), .Sum(sum_final));

  // Assign the final sum to the output.
  //assign Sum = {{8{sum_final[7]}}, sum_final};

  // Get the expected first level sums.

  wire [4:0] sum_ae, sum_bf, sum_cg, sum_dh; // First-level sums (4-bit chunks).
  wire [5:0] sum_aebf, sum_cgdh; // Second-level 8-bit sum results.
  wire [6:0] sum_final; // Third-level sum result.

  // Get the expected first level sums.
  assign sum_ae = $signed(A[15:12]) + $signed(B[15:12]);
  assign sum_bf = $signed(A[11:8]) + $signed(B[11:8]);
  assign sum_cg = $signed(A[7:4]) + $signed(B[7:4]);
  assign sum_dh = $signed(A[3:0]) + $signed(B[3:0]);

  // Get the expected second level sums.
  assign sum_aebf = $signed(sum_ae) + $signed(sum_bf);
  assign sum_cgdh = $signed(sum_cg) + $signed(sum_dh);

  // Get the expected sum.
  assign sum_final = $signed(sum_aebf) + $signed(sum_cgdh);
  assign Sum = {{9{sum_final[6]}}, sum_final};

endmodule

`default_nettype wire // Reset default behavior at the end
