`default_nettype none

module ControlUnit(Opcode, ALUSrc, MemtoReg, RegWrite, RegSrc1, MemRead, MemWrite, Branch, HLT, PCS, ALUOp);

    input wire [3:0] Opcode; // Opcode of the current instruction
    output wire ALUSrc; // Determines whether to use the immediate or register-value as the ALU input
    output wire MemtoReg; // Allows for choosing between writing from the ALU or memory output to the register file
    output wire RegWrite; // Determines if the register file is being written to
    output wire RegSrc1; // Determines if the read register port 1 should use rs or rd, which is read from for LLB/LHB operations
    output wire MemEnable; // Looks for whether the memory unit is used in this operation
    output wire MemWrite; // Looks for whether the memory unit is written to in this operation
    output wire Branch; // Used to signal that the PC should take the value from the branch adder
    output wire HLT; // Used to signal an HLT instruction
    output wire PCS; // Used to signal a PCS instruction
    output wire [3:0] ALUOp; // Control lines into the ALU to allow for the unit to determine its operation

    // ALUSrc must be 1 for SLL, SRA, ROR, LW, SW, LLB, and LHB
    assign ALUSrc = (Opcode[3]) | (Opcode[2] & ~Opcode[1]) | (Opcode[2] & Opcode[1] & ~Opcode[0]);

    // MemtoReg must be 1 for LW instruction
    assign MemtoReg = Opcode[3] & ~Opcode[1];

    // RegWrite must be 1 for ADD, SUB, XOR, RED, SLL, SRA, ROR, PADDSB, LW, LLB, LHB, and PCS
    assign RegWrite = (~Opcode[3]) | (Opcode[1]) | (Opcode[3] & ~Opcode[2] & ~Opcode[0]);

    // RegSrc1 must be 1 for LLB and LHB
    assign RegSrc1 = Opcode[3] & Opcode[1];

    // MemEnable is on for SW or LW
    assign MemEnable = Opcode[3] & ~Opcode[2] & ~Opcode[1];

    // MemWrite is only 1 for SW
    assign MemWrite = Opcode[3] & ~Opcode[2] & ~Opcode[1] & Opcode[0];

    // Branch is only 1 for B and BR
    assign Branch = Opcode[3] & Opcode[2] & ~Opcode[1];
    
    // The ALU control lines are set to the opcode to allow it to perform the
    // necessary operation for the given instruction
    assign ALUOp = Opcode;

    // HLT Opcode = 1111
    assign HLT = &Opcode[3:0];

    // PCS Opcode = 1110
    assign PCS = Opcode[3] & Opcode[2] & Opcode[1] & ~Opcode[0];

endmodule

`default_nettype wire