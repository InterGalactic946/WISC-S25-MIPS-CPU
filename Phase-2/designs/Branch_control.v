`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////////////
// Branch_control.v: Branch Control Unit                    //
//                                                          //
// This module implements the branch control logic for the  //
// CPU. It determines whether a branch should be taken      //
// based on the condition code (`C`), an immediate offset   //
// (`I`), the flag register (`F`), and the source register  //
// (`Rs`).                                                  //
//                                                          //
// The output `Branch_taken` indicates if the branch is     //
// taken, and `PC_branch` provides the computed branch      //
// target address. `PC_next` is the next program counter    //
// value, considering both sequential execution and branch  //
// control decisions.                                       //
//////////////////////////////////////////////////////////////
module Branch_control(C, I, F, Rs, Branch, BR, PC_next, Branch_taken, PC_branch);
  
  input wire [2:0] C;           // 3-bit condition code
  input wire [8:0] I;           // 9-bit signed offset right shifted by one
  input wire [2:0] F;           // 3-bit flag register inputs for (F[2] = Z, F[1] = V, F[0] = N)
  input wire [15:0] Rs;         // Register source input for the BR instruction
  input wire Branch;            // Indicates a branch instruction
  input wire BR;                // indicates a BR instruction vs a B instruction
  input wire [15:0] PC_next;    // 16-bit address of the next (PC+2) instruction (from the fetch stage)
  output wire Branch_taken;     // Signal used to determine whether branch is taken
  output wire [15:0] PC_branch; // 16-bit address of the branch target

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire [15:0] sext_offset;    // Sign-extended offset.
  wire [15:0] shifted_offset; // Shifted offset for the BR instruction.
  wire taken;                 // Signal used to determine whether the branch condition codes are met.
  wire [15:0] PC_B;           // The PC value in case branch is taken (for B).
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////
  // Implement Branch_control as structural/dataflow verilog //
  ////////////////////////////////////////////////////////////
  // Instantiate the Branch adder.
  CLA_16bit iCLA_branch (.A(PC_next), .B(shifted_offset), .sub(1'b0), .Sum(PC_B), .Cout(), .Ovfl(), .pos_Ovfl(), .neg_Ovfl());

  // Sign extend the 9-bit offset to 16 bits.
  assign sext_offset = {{7{I[8]}}, I};

  // Shift the sign extended offset left by one for the BR instruction.
  assign shifted_offset = {sext_offset[14:0], 1'b0};

  // The branch is taken either unconditionally when C = 3'b111 or when the conditon code matches the flag register setting.
  assign taken = (C == 3'b000) ? ~F[2]                    : // Not Equal (Z = 0)
                 (C == 3'b001) ? F[2]                     : // Equal (Z = 1)
                 (C == 3'b010) ? (~F[2] & ~F[0])          : // Greater Than (Z = N = 0)
                 (C == 3'b011) ? F[0]                     : // Less Than (N = 1)
                 (C == 3'b100) ? (F[2] | (~F[2] & ~F[0])) : // Greater Than or Equal (Z = 1 or Z = N = 0)
                 (C == 3'b101) ? (F[2] | F[0])            : // Less Than or Equal (Z = 1 or N = 1)
                 (C == 3'b110) ? F[1]                     : // Overflow (V = 1)
                 (C == 3'b111) ? 1'b1                     : // Unconditional (always executes)
                 1'b0;                                      // Default: Condition not met (shouldn't happen if ccc is valid)

  // The branch is taken when it is a branch instruction and the condition codes are met.
  assign Branch_taken = Branch & taken;

  // Update the branch target address with the B instruction's computed offset or contents of Rs if it is a BR instruction.
  assign PC_branch = (BR) ? Rs : PC_B;

endmodule

`default_nettype wire // Reset default behavior at the end