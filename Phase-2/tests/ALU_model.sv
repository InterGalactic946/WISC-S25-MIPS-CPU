//////////////////////////////////////////////////////////////
// ALU_model.sv: Model ALU module for the 16-bit model CPU. //
// This design performs arithmetic and logical              //
// operations on two 16-bit vectors based on the opcode.    //
//////////////////////////////////////////////////////////////

import ALU_tasks::*;

module ALU_model (ALU_Out, Z_set, V_set, N_set, ALU_In1, ALU_In2, Opcode);

  input logic [15:0] ALU_In1, ALU_In2;  // First and second ALU operands
  input logic [3:0]  Opcode;            // Opcode field of the ALU
  output logic [15:0] ALU_Out;          // Result of the ALU operation
  output logic Z_set, V_set, N_set;     // (Z/V/N) set signals for the flag register

  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  // ADD/SUB signals
  logic ov, pos_ov, neg_ov;       // Overflow indicators for addition/subtraction
  logic [15:0] Input_A, Input_B;  // 16-bit inputs modified to the ALU
  logic [15:0] SUM_Out, SUM_step; // Sum result with saturation handling

  // Flag signals
  logic error;                   // Error flag raised when opcode is invalid.
  /////////////////////////////////////////////////////////////////////////////////////////

  // Modify inputs for LW/SW instructions vs. normal ADD.
  assign Input_A = (Opcode[3:1] == 3'h4) ? ALU_In1 & 16'hFFFE : ALU_In1;
  assign Input_B = (Opcode[3:1] == 3'h4) ? {ALU_In2[14:0], 1'b0} : ALU_In2;

  // Form the step sum.
  assign SUM_step = (Opcode == 4'h1) ? (Input_A - Input_B) : (Input_A + Input_B);  

  // Overflow detection logic (only for ADD and SUB).
  assign pos_ov =  ((Opcode == 4'h0 && ~Input_A[15] && ~Input_B[15] && SUM_step[15]) || // ADD Overflow
                   (Opcode == 4'h1 && ~Input_A[15] && Input_B[15] && SUM_step[15]));  // SUB Overflow

  assign neg_ov =  ((Opcode == 4'h0 && Input_A[15] && Input_B[15] && ~SUM_step[15]) || // ADD Negative Overflow
                   (Opcode == 4'h1 && Input_A[15] && ~Input_B[15] && ~SUM_step[15])); // SUB Negative Overflow

  // Saturate result based on overflow condition for ADD/SUB but wrap around if LW/SW.
  assign SUM_Out = (Opcode[3:1] === 3'h0) ? 
                   ((pos_ov) ? 16'h7FFF : 
                    (neg_ov) ? 16'h8000 : SUM_step) 
                  : SUM_step;

  //////////////////////////////////////////////
  // Generate ALU output based on the opcode //
  ////////////////////////////////////////////
  always_comb begin
      error = 1'b0;  
      ALU_Out = 16'h0000;
      case (Opcode)
          4'h0, 4'h1, 4'h8, 4'h9: ALU_Out = SUM_Out;
          4'h2: ALU_Out = Input_A ^ Input_B; // XOR
          4'h3: get_red_sum(.A(Input_A), .B(Input_B), .expected_sum(ALU_Out)); // RED
          4'h4, 4'h5, 4'h6: get_shifted_result(.A(Input_A), .B(Input_B[3:0]), 
                                                .mode(Opcode[1:0]), 
                                                .expected_result(ALU_Out)); // SLL/SRA/ROR
          4'h7: get_paddsb_sum(.A(Input_A), .B(Input_B), .expected_result(ALU_Out)); // PADDSB
          4'hA, 4'hB: get_LB_result(.A(Input_A), .B(Input_B), .mode(Opcode[0]), 
                                    .expected_result(ALU_Out)); // LLB/LHB
          default: begin
              ALU_Out = 16'h0000;
              error = 1'b1;
          end
      endcase
  end

  ////////////////////////////////////////////
  // Set flag signals based on ALU output  //
  //////////////////////////////////////////
  // Z_flag is set when ALU_Out is zero.
  assign Z_set = (ALU_Out === 16'h0000);

  // V_flag is set for overflow conditions in ADD/SUB operations.
  assign V_set = pos_ov || neg_ov;

  // N_flag is set when the sum result is negative.
  assign N_set = ALU_Out[15];
  //////////////////////////////////////////////////////////////////////////////////////////

endmodule

`default_nettype wire  // Reset default behavior at the end