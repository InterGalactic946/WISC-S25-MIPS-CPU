//////////////////////////////////////////////////////////////
// PC_control.sv: Model Program Counter Control             //
//                                                          //
// This module implements the control logic for the         //
// Program Counter (PC). It determines the next PC value    //
// based on the condition code (`C`), an immediate offset   //
// (`I`), and the flag register (`F`).                      //
//                                                          //
// The input `PC_in` represents the current PC value, and   //
// `PC_out` is the computed next instruction address. The   //
// condition code (`C`) and flags (`F`) dictate whether a   //
// branch should be taken using the signed offset `I`.      //
//////////////////////////////////////////////////////////////
module PC_control_model (C, I, F, Branch, Rs, BR, PC_in, PC_out);
  
  input logic [2:0] C;        // 3-bit condition code
  input logic [8:0] I;        // 9-bit signed offset right shifted by one
  input logic [2:0] F;        // 3-bit flag register inputs for (F[2] = Z, F[1] = V, F[0] = N)
  input logic [15:0] Rs;      // Register source input for the BR instruction
  input logic Branch;         // Indicates a branch instruction.
  input logic BR;             // indicates a BR instruction vs a B instruction
  input logic [15:0] PC_in;   // 16-bit address of the current instruction
  output logic [15:0] PC_out; // 16-bit address of the new instruction

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic [15:0] sext_offset;    // Sign-extended offset.
  logic [15:0] shifted_offset; // Shifted offset for the BR instruction.
  logic [15:0] PC_next;        // The next PC value.
  logic [15:0] PC_B;           // The PC value in case branch is taken (for B).
  logic Branch_taken;          // Signal used to determine whether branch is taken.
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////
  // Implement Branch_control as structural/dataflow verilog //
  ////////////////////////////////////////////////////////////
  // Infer the PC adder.
  assign PC_next = PC_in + 16'h0002;

  // Infer the Branch adder.
  assign PC_B = PC_next + ($signed(sext_offset) <<< 1'b1);

  // Sign extend the 9-bit offset to 16 bits.
  assign sext_offset = {{7{I[8]}}, I};

  // The branch is taken either unconditionally when C = 3'b111 or when the conditon code matches the flag register setting.
  assign Branch_taken = (C == 3'b000) ? ~F[2]                    : // Not Equal (Z = 0)
                        (C == 3'b001) ? F[2]                     : // Equal (Z = 1)
                        (C == 3'b010) ? (~F[2] & ~F[0])          : // Greater Than (Z = N = 0)
                        (C == 3'b011) ? F[0]                     : // Less Than (N = 1)
                        (C == 3'b100) ? (F[2] | (~F[2] & ~F[0])) : // Greater Than or Equal (Z = 1 or Z = N = 0)
                        (C == 3'b101) ? (F[2] | F[0])            : // Less Than or Equal (Z = 1 or N = 1)
                        (C == 3'b110) ? F[1]                     : // Overflow (V = 1)
                        (C == 3'b111) ? 1'b1                     : // Unconditional (always executes)
                        1'b0;                                      // Default: Condition not met (shouldn't happen if ccc is valid)

  // Update the PC_out with the next PC or branched PC (BR or B) based on conditional check.
  assign PC_out = (Branch_taken & Branch) ? ((BR) ? Rs : PC_B) : PC_next;

endmodule