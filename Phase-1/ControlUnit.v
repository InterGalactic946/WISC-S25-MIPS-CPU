`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////
// ControlUnit.v: Control Unit Module                    //  
//                                                       //
// This module generates control signals for the         //
// processor based on the given 4-bit opcode. It         //
// determines ALU operation, memory access, register     //
// writes, and branch behavior to facilitate execution   //
// of various instructions.                              //
///////////////////////////////////////////////////////////
module ControlUnit(Opcode, ALUSrc, MemtoReg, RegWrite, RegSrc, MemEnable, MemWrite, Branch, HLT, PCS, ALUOp, Z_en, NV_en);

    input wire [3:0] Opcode; // Opcode of the current instruction
    output wire ALUSrc;      // Determines whether to use the immediate or register-value as the ALU input
    output wire MemtoReg;    // Allows for choosing between writing from the ALU or memory output to the register file
    output wire RegWrite;    // Determines if the register file is being written to
    output wire RegSrc;      // Determines if the read register port 1 should use rs or rd, which is read from for LLB/LHB operations
    output wire MemEnable;   // Looks for whether the memory unit is used in this operation
    output wire MemWrite;    // Looks for whether the memory unit is written to in this operation
    output wire Branch;      // Used to signal that the PC should take the value from the branch adder
    output wire HLT;         // Used to signal an HLT instruction
    output wire PCS;         // Used to signal a PCS instruction
    output wire [3:0] ALUOp; // Control lines into the ALU to allow for the unit to determine its operation
    output wire Z_en;        // Signal to turn on the Z flag registers
    output wire NV_en;      // Signal to turn on the N and V flag registers

    //////////////////////////////////////////////////////
    // Generate control signals by decoding the opcode //
    ////////////////////////////////////////////////////
    // ALUSrc must be 1 for SLL, SRA, ROR, LW, SW, LLB, and LHB
    assign ALUSrc = (Opcode[3]) | (Opcode[2] & ~Opcode[1]) | (Opcode[2] & Opcode[1] & ~Opcode[0]);

    // MemtoReg must be 1 for LW instruction
    assign MemtoReg = Opcode[3] & ~Opcode[1];

    // RegWrite must be 1 for ADD, SUB, XOR, RED, SLL, SRA, ROR, PADDSB, LW, LLB, LHB, and PCS
    assign RegWrite = ((~Opcode[3]) | (Opcode[1]) | (Opcode[3] & ~Opcode[2] & ~Opcode[0])) & ~(Opcode[3] | Opcode[2] | Opcode[1] | Opcode[0]);

    // RegSrc must be 1 for LLB and LHB
    assign RegSrc = Opcode[3] & Opcode[1];

    // MemEnable must be 1 for SW and LW
    assign MemEnable = Opcode[3] & ~Opcode[2] & ~Opcode[1];

    // MemWrite is only 1 for SW
    assign MemWrite = Opcode[3] & ~Opcode[2] & ~Opcode[1] & Opcode[0];

    // Branch is only 1 for B and BR
    assign Branch = Opcode[3] & Opcode[2] & ~Opcode[1];
    
    // The ALU control lines are set to the opcode to allow it to perform the
    // necessary operation for the given instruction
    assign ALUOp = Opcode;

    // HLT Opcode = 0x1111
    assign HLT = &Opcode;

    // PCS Opcode = 0x1110
    assign PCS = Opcode[3] & Opcode[2] & Opcode[1] & ~Opcode[0];
    
    // Z_en is enabled for all ALU instructions except PADDSB and RED.
    assign Z_en = ~Opcode[3] & (~Opcode[1] | ~Opcode[0]);
  
    // NV_en is enabled for just ADD and SUB instructions.
    assign NV_en = Opcode[3:1] == 3'h0;

endmodule

`default_nettype wire  // Reset default behavior at the end
