//////////////////////////////////////////////////////////////
// ALU_model.sv: Model ALU module for the 16-bit model CPU. //
// This design performs arithmetic and logical              //
// operations on two 16-bit vectors based on the opcode.    //
//////////////////////////////////////////////////////////////
module ALU (ALU_Out, Z_set, V_set, N_set, ALU_In1, ALU_In2, Opcode);

  input logic [15:0] ALU_In1, ALU_In2;  // First and second ALU operands
  input logic [3:0]  Opcode;            // Opcode field of the ALU
  output logic [15:0] ALU_Out;          // Result of the ALU operation
  output logic Z_set, V_set, N_set;     // (Z/V/N) set signals for the flag register

  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  // ADD/SUB signals
  logic pos_ov_add, neg_ov_add;   // Overflow indicators for addition/subtraction
  logic pos_ov_sub, neg_ov_sub;   // Overflow indicators for addition/subtraction
  logic pos_ov, neg_ov;           // Overflow indicators for addition/subtraction
  logic [15:0] Input_A, Input_B;  // 16-bit inputs modified to the ALU
  logic [15:0] SUM_Out, SUM_step; // Sum result with saturation handling

  // PADDSB signals
  logic [15:0] PADDSB_Out;

  // RED signals
  logic signed [4:0] sum_ae, sum_bf, sum_cg, sum_dh; // First-level sums (4-bit chunks).
  logic signed [5:0] sum_aebf, sum_cgdh; // Second-level 8-bit sum results.
  logic signed [6:0] sum_final; // Third-level sum result.
  logic signed [15:0] RED_Out;

  // Shifted final stage value for each mode
  logic signed [15:0] Shift_Out;    

  // LLB/LHB signals
  logic [15:0] LLB_Out, LHB_Out;

  // Flag signals
  logic error;                   // Error flag raised when opcode is invalid.
  /////////////////////////////////////////////////////////////////////////////////////////

  // Modify inputs for LW/SW instructions vs. normal ADD.
  assign Input_A = (Opcode[3:1] == 3'h4) ? ALU_In1 & 16'hFFFE : ALU_In1;
  assign Input_B = (Opcode[3:1] == 3'h4) ? {ALU_In2[14:0], 1'b0} : ALU_In2;

  // Form the step sum.
  assign SUM_step = (Opcode == 4'h1) ? (Input_A - Input_B) : (Input_A + Input_B);  

  // Overflow detection for ADD
  assign pos_ov_add = (~Input_A[15] & ~Input_B[15] & SUM_step[15]); // Both positive → Negative result
  assign neg_ov_add = ( Input_A[15] &  Input_B[15] & ~SUM_step[15]); // Both negative → Positive result

  // Overflow detection for SUB (A - B) is actually A + (~B + 1)
  assign pos_ov_sub = (~Input_A[15] &  Input_B[15] & SUM_step[15]); // A positive, B negative → Negative result
  assign neg_ov_sub = ( Input_A[15] & ~Input_B[15] & ~SUM_step[15]); // A negative, B positive → Positive result

  // Final overflow signals: Apply conditions based on ADD (Opcode = 4'h0) or SUB (Opcode = 4'h1)
  assign pos_ov = ((Opcode == 4'h0) & pos_ov_add) | ((Opcode == 4'h1) & pos_ov_sub);
  assign neg_ov = ((Opcode == 4'h0) & neg_ov_add) | ((Opcode == 4'h1) & neg_ov_sub);

  // Saturate result based on overflow condition for ADD/SUB but wrap around if LW/SW.
  assign SUM_Out = (Opcode[3:1] === 3'h0) ? 
                   ((pos_ov) ? 16'h7FFF : 
                    (neg_ov) ? 16'h8000 : SUM_step) 
                  : SUM_step;

  ///////////////////////////////////////////////////////////////
  // Implement PADDSB functionality using a PSA_16bit module  //
  /////////////////////////////////////////////////////////////
  PSA_16bit iPSA (.A(Input_A), .B(Input_B), .Sum(PADDSB_Out));

  //////////////////////////////////////////////////////////
  // Implement RED functionality using a RED_Unit module //
  ////////////////////////////////////////////////////////
  // Get the expected first level sums.
  assign sum_ae = $signed(Input_A[15:12]) + $signed(Input_B[15:12]);
  assign sum_bf = $signed(Input_A[11:8]) + $signed(Input_B[11:8]);
  assign sum_cg = $signed(Input_A[7:4]) + $signed(Input_B[7:4]);
  assign sum_dh = $signed(Input_A[3:0]) + $signed(Input_B[3:0]);

  // Get the expected second level sums.
  assign sum_aebf = $signed(sum_ae) + $signed(sum_bf);
  assign sum_cgdh = $signed(sum_cg) + $signed(sum_dh);

  // Get the expected sum.
  assign sum_final = $signed(sum_aebf) + $signed(sum_cgdh);
  assign RED_Out = {{9{sum_final[6]}}, sum_final};
  
  //////////////////////////////////////////////////////////
  // Implement SLL/SRA/ROR functionality using a Shifter //
  ////////////////////////////////////////////////////////
  Shifter iSHIFT (.Shift_In(Input_A), .Mode(Opcode[1:0]), .Shift_Val(Input_B[3:0]), .Shift_Out(Shift_Out));

  ///////////////////////////////////////////////////
  // Implement LLB/LHB functionality using a MUX  //
  /////////////////////////////////////////////////
  // Loads lower byte of Input_A register with 8-bits of the immediate value. 
  assign LLB_Out = (Opcode[3:0] == 4'hA) ? ((Input_A & 16'hFF00) | (Input_B[7:0])) : 16'h0000;

  // Loads higher byte of Input_A register with 8-bits of the immediate value, shifted left.
  assign LHB_Out = (Opcode[3:0] == 4'hB) ? ((Input_A & 16'h00FF) | ({Input_B[7:0], 8'h00})) : 16'h0000;

  //////////////////////////////////////////////
  // Generate ALU output based on the opcode //
  ////////////////////////////////////////////
  always_comb begin
      error = 1'b0;  
      ALU_Out = 16'h0000;
      case (Opcode)
          4'h0, 4'h1, 4'h8, 4'h9: ALU_Out = SUM_Out;
          4'h2: ALU_Out = Input_A ^ Input_B; // XOR
          4'h3: ALU_Out = RED_Out; // RED
          4'h4, 4'h5, 4'h6: ALU_Out = Shift_Out; // SLL/SRA/ROR
          4'h7: ALU_Out = PADDSB_Out; // PADDSB
          4'hA: ALU_Out = LLB_Out; // LLB
          4'hB: ALU_Out = LHB_Out; // LHB
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
  assign Z_set = (ALU_Out == 16'h0000);

  // V_flag is set for overflow conditions in ADD/SUB operations.
  assign V_set = pos_ov | neg_ov;

  // N_flag is set when the sum result is negative.
  assign N_set = ALU_Out[15];
  //////////////////////////////////////////////////////////////////////////////////////////

endmodule