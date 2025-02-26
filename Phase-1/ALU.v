`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////////
// ALU.v: ALU module for the 16-bit ALU design.             //
// This design performs aritmetic and logical              //
// operarations on two 16-bit vectors based on the opcode.//
///////////////////////////////////////////////////////////
module ALU(ALU_Out, Error, ALU_In1, ALU_In2, Opcode);

  input wire [15:0] ALU_In1, ALU_In2; // First and second ALU operands
  input wire [3:0] Opcode;	          // Opcode field of the ALU
  output reg [15:0] ALU_Out;          // Result of the ALU operation
  output wire Z_set, V_set, N_set;	  // (Z/V/N) set signals for the flag register

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  ///////////////////// ADD/SUB signals /////////////////
  wire ov, pos_ov, neg_ov;       // Overflow indicators of the addition/subtraction.
  wire [15:0] Input_A, Input_B;  // 16-bit inputs to the CLA adder.
  wire [15:0] SUM_Out, SUM_step; // 16-bit sum formed on addition/subtraction of the given operands and saturates during overflow.
  /////////////////// XOR signals ////////////////////////////////
  wire [15:0] XOR_Out;
  /////////////////// PADDSB signals /////////////////////////////
  wire [15:0] PADDSB_Out;
  /////////////////// RED signals ///////////////////////////////
  wire [15:0] RED_Out;
  /////////////////// SLL/SRA/ROR signals ///////////////////////
  wire [15:0] Shift_Out;
  //////////////////////////////////////////////////////////////
  reg error; // Error flag raised when opcode is not compliant.
  //////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////
  // Implement ADD/SUB functionality of ALU using a CLA //
  ///////////////////////////////////////////////////////
  // Get the first input based on whether it is a LW/SW vs. a normal ADD instruction.
  assign Input_A = (Opcode[3:1] == 3'h4) ? ALU_In1 & 0xFFFE : ALU_In1;

  // Get the second input based on whether it is a LW/SW vs. a normal ADD instruction.
  assign Input_B = (Opcode[3:1] == 3'h4) ? ALU_In2 << 1'b1 : ALU_In2;

  // Instantiate a 16-bit CLA for ADD/SUB instructions.                      
  CLA_16bit iCLA (.A(Input_A), .B(Input_B), .sub((Opcode == 4'h1)), .Sum(SUM_step), .Cout(), .Ovfl(ov), .pos_Ovfl(pos_ov), .neg_Ovfl(neg_ov));

  // Saturate to the most positve/negative number in 16-bits based on the overflow condition.
  assign SUM_Out = (pos_ov) ? 16'h7FFF : 
                   (neg_ov) ? 16'h8000 : SUM_step;
  ///////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////
  // Implement XOR functionality of ALU with bitwise operations //
  ///////////////////////////////////////////////////////////////
  assign XOR_Out = ALU_In1 ^ ALU_In2;
  ///////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////
  // Implement PADDSB functionality of ALU using the PSA_16bit //
  //////////////////////////////////////////////////////////////
  // Instantiate a 16-bit PSA for the PADDSB instruction.                      
  PSA_16bit iPSA (.A(ALU_In1), .B(ALU_In2), .Sum(PADDSB_Out), .Error());
  ///////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////
  // Implement RED functionality of ALU using the RED_Unit //
  //////////////////////////////////////////////////////////
  // Instantiate the reduction unit for the RED instruction.                      
  RED_Unit iRED (.A(ALU_In1), .B(ALU_In2), .Sum(RED_Out));
  ///////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////
  // Implement SLL/SRA/ROR functionality of ALU using the Shifter //
  /////////////////////////////////////////////////////////////////
  // Instantiate the shifter for the SLL/SRA/ROR instructions.                      
  Shifter iSHIFT (.Shift_In(ALU_In1), .Mode(Opcode[1:0]), .Shift_Val(ALU_In2[3:0]), .Shift_Out(Shift_Out));
  ///////////////////////////////////////////////////////////

  // The ALU output is formed based on the opcode passed in. 
  always @(*) begin
      case (Opcode)
          4'b0000, 4'b0001, 4'b1000, 4'b1001:  ALU_Out = sum;  // Opcodes ADD/SUB/LW/SW -> SUM_Out
          4'b0010: ALU_Out = XOR_Out;   // Opcode 2 -> XOR output
          4'b0011: ALU_Out = RED_Out;   // Opcode 3 -> RED output
          4'b0100, 4'b0101, 4'b0110: ALU_Out = SHIFT_Out; // Opcodes SLL/SRA/ROR -> SHIFT_Out
          4'b0111: ALU_Out = PADDSB_Out;// Opcode PADDSB -> PADDSB_Out
          default: ALU_Out = 16'h0000;  // Default case (don't care)
      endcase
  end

  // Set the Z/F/N flags based on the opcode.
  always @(*) begin
      case (Opcode)
          4'b0000, 4'b0001: Z_set = (ALU_Out == 16'h0000) ? 1'b1 : 1'b0;
          4'b0010: ALU_Out = XOR_Out;   // Opcode 2 -> XOR output
          4'b0011: ALU_Out = RED_Out;   // Opcode 3 -> RED output
          4'b0100, 4'b0101, 4'b0110: ALU_Out = SHIFT_Out; // Opcodes SLL/SRA/ROR -> SHIFT_Out
          4'b0111: ALU_Out = PADDSB_Out;// Opcode PADDSB -> PADDSB_Out
          default: ALU_Out = 16'h0000;  // Default case (don't care)
      endcase
  end
  ///////////////////////////////////////////////////////////
					 
endmodule

`default_nettype wire  // Reset default behavior at the end