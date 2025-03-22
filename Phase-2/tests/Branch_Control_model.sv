//////////////////////////////////////////////////////////////
// Branch_control_model.sv: Model Branch Control Unit       //
//                                                          //
// This module implements the branch control logic for the  //
// model CPU. It determines whether a branch should be      //
// taken based on the condition code (`C`), an immediate    //
// offset (`I`), the flag register (`F`), and the source    //
// register (`Rs`).                                         //
//////////////////////////////////////////////////////////////
module Branch_Control_model (C, I, F, Rs, BR, PC_next, taken, PC_branch);
  
  input logic [2:0] C;           // 3-bit condition code
  input logic [8:0] I;           // 9-bit signed offset right shifted by one
  input logic [2:0] F;           // 3-bit flag register inputs for (F[2] = Z, F[1] = V, F[0] = N)
  input logic [15:0] Rs;         // Register source input for the BR instruction
  input logic BR;                // indicates a BR instruction vs a B instruction
  input logic [15:0] PC_next;    // 16-bit address of the next (PC+2) instruction (from the fetch stage)
  
  output logic taken;            // Signal used to determine whether branch instruction met condition codes
  output logic [15:0] PC_branch; // 16-bit address of the branch target

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic [15:0] sext_offset;    // Sign-extended offset.
  logic [15:0] PC_B;           // The PC value in case branch is taken (for B).
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////
  // Implement Branch_control as structural/dataflow verilog //
  ////////////////////////////////////////////////////////////
  // Infer the Branch adder.
  assign PC_B = PC_next + ($signed(sext_offset) <<< 1'b1);

  // Sign extend the 9-bit offset to 16 bits.
  assign sext_offset = {{7{I[8]}}, I};

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
  
  // Update the branch target address with the B instruction's computed offset or contents of Rs if it is a BR instruction.
  assign PC_branch = (BR) ? Rs : PC_B;

endmodule

`default_nettype wire // Reset default behavior at the end