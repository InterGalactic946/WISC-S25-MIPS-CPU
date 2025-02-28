`default_nettype none  // Set the default as none to avoid errors

//////////////////////////////////////////////////////////////
// ALU.v: ALU module for the 16-bit ALU design.             //
// This design performs arithmetic and logical              //
// operations on two 16-bit vectors based on the opcode.    //
//////////////////////////////////////////////////////////////
module ALU (ALU_Out, Error, ALU_In1, ALU_In2, Opcode);

  input wire [15:0] ALU_In1, ALU_In2;  // First and second ALU operands
  input wire [3:0]  Opcode;            // Opcode field of the ALU
  output reg [15:0] ALU_Out;           // Result of the ALU operation
  output wire Z_set, V_set, N_set;     // (Z/V/N) set signals for the flag register

  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  // ADD/SUB signals
  wire ov, pos_ov, neg_ov;       // Overflow indicators for addition/subtraction
  wire [15:0] Input_A, Input_B;  // 16-bit inputs to the CLA adder
  wire [15:0] SUM_Out, SUM_step; // Sum result with saturation handling

  // XOR signals
  wire [15:0] XOR_Out;

  // PADDSB signals
  wire [15:0] PADDSB_Out;

  // RED signals
  wire [15:0] RED_Out;

  // SLL/SRA/ROR signals
  wire [15:0] Shift_Out;

  // Flag signals
  reg error;                   // Error flag raised when opcode is invalid.
  wire z_flag, v_flag, n_flag; // z, v, n flags set based on the result of the operation.
  /////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////
  // Implement ADD/SUB functionality of ALU using a CLA  //
  ////////////////////////////////////////////////////////
  // Modify inputs for LW/SW instructions vs. normal ADD.
  assign Input_A = (Opcode[3:1] == 3'h4) ? ALU_In1 & 16'hFFFE : ALU_In1;
  assign Input_B = (Opcode[3:1] == 3'h4) ? ALU_In2 << 1'b1 : ALU_In2;

  // Instantiate a 16-bit CLA for ADD/SUB instructions.
  CLA_16bit iCLA (.A(Input_A), .B(Input_B), .sub(Opcode == 4'h1), .Sum(SUM_step), .Cout(), .Ovfl(ov), .pos_Ovfl(pos_ov), .neg_Ovfl(neg_ov));

  // Saturate result based on overflow condition.
  assign SUM_Out = (pos_ov) ? 16'h7FFF : 
                   (neg_ov) ? 16'h8000 : SUM_step;
  /////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////
  // Implement XOR functionality of ALU using bitwise XOR //
  /////////////////////////////////////////////////////////
  assign XOR_Out = ALU_In1 ^ ALU_In2;

  ///////////////////////////////////////////////////////////////
  // Implement PADDSB functionality using a PSA_16bit module  //
  /////////////////////////////////////////////////////////////
  PSA_16bit iPSA (.A(ALU_In1), .B(ALU_In2), .Sum(PADDSB_Out));

  //////////////////////////////////////////////////////////
  // Implement RED functionality using a RED_Unit module //
  ////////////////////////////////////////////////////////
  RED_Unit iRED (.A(ALU_In1), .B(ALU_In2), .Sum(RED_Out));

  //////////////////////////////////////////////////////////
  // Implement SLL/SRA/ROR functionality using a Shifter //
  ////////////////////////////////////////////////////////
  Shifter iSHIFT (.Shift_In(ALU_In1), .Mode(Opcode[1:0]), .Shift_Val(ALU_In2[3:0]), .Shift_Out(Shift_Out));

  //////////////////////////////////////////////
  // Generate ALU output based on the opcode //
  ////////////////////////////////////////////
  always @(*) begin
      error = 1'b0;  // Default error state.
      case (Opcode)
          4'h0, 4'h1, 4'h8, 4'h9: ALU_Out = SUM_Out; // ADD/SUB/LW/SW
          4'h2: ALU_Out = XOR_Out; // XOR
          4'h3: ALU_Out = RED_Out; // RED
          4'h4, 4'h5, 4'h6: ALU_Out = Shift_Out; // SLL/SRA/ROR
          4'h7: ALU_Out = PADDSB_Out; // PADDSB
          default: error = 1'b1; // Invalid opcode
      endcase
  end
  ////////////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////
  // Set flag signals based on ALU output  //
  //////////////////////////////////////////
  // z_flag is set when ALU_Out is zero, relevant for ADD/SUB/XOR/SLL/SRA/ROR.
  assign z_flag = (ALU_Out == 16'h0000);

  // v_flag is set for overflow conditions in ADD/SUB operations.
  assign v_flag = ov;

  // n_flag is set when the sum result is negative, only for ADD/SUB.
  assign n_flag = SUM_Out[15];

  // Assign conditionally set flags.
  assign N_set = (Opcode == 4'h0 | Opcode == 4'h1) ? n_flag : 1'b0;
  assign V_set = (Opcode == 4'h0 | Opcode == 4'h1) ? v_flag : 1'b0;
  assign Z_set = ((Opcode == 4'h0) | (Opcode == 4'h1) | (Opcode == 4'h2) |
                 (Opcode == 4'h4)  | (Opcode == 4'h5) | (Opcode == 4'h6)) ? z_flag : 1'b0;
  //////////////////////////////////////////////////////////////////////////////////////////

endmodule

`default_nettype wire  // Reset default behavior at the end