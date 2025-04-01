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
module ControlUnit (
    input wire [3:0] Opcode,                  // Opcode of the current instruction
    input wire actual_taken,                  // Indicates if the branch was actually taken
    input wire IF_ID_predicted_taken,         // Predicted taken value from the branch predictor
    input wire [15:0] IF_ID_predicted_target, // Predicted target address from the branch predictor of the previous instruction
    input wire [15:0] actual_target,          // Actual target address computed by the ALU
    
    output wire Branch,                       // Used to signal that the PC fetched a branch instruction
    output wire wen_BTB,                      // Write enable for BTB (Branch Target Buffer)
    output wire wen_BHT,                      // Write enable for BHT (Branch History Table)
    output wire update_PC,                    // Signal to update the PC with the actual target

    output wire [3:0] ALUOp,                  // Control lines into the ALU to allow for the unit to determine its operation
    output wire ALUSrc,                       // Determines whether to use the immediate or register-value as the ALU input
    output wire RegSrc,                       // Determines if the read register port 1 should use rs or rd, which is read from for LLB/LHB operations
    output wire Z_en,                         // Signal to turn on the Z flag registers
    output wire NV_en,                        // Signal to turn on the N and V flag registers
    
    output wire MemEnable,                    // Looks for whether the memory unit is used in this operation
    output wire MemWrite,                     // Looks for whether the memory unit is written to in this operation

    output wire RegWrite,                     // Determines if the register file is being written to
    output wire MemtoReg,                     // Allows for choosing between writing from the ALU or memory output to the register file
    output wire HLT,                          // Used to signal an HLT instruction
    output wire PCS                          // Used to signal a PCS instruction
);

    /////////////////////////////////////////////////
    // Declare any internal signals as type wire  //
    ///////////////////////////////////////////////
    wire mispredicted;        // Indicates previous instruction's fetch mispredicted.
    wire target_miscomputed;  // Indicates previous instruction's fetch miscomputed the target.
    wire branch_taken;        // Indicates branch was actually taken.
    ////////////////////////////////////////////////

    //////////////////////////////////////////////////////
    // Generate control signals by decoding the opcode //
    ////////////////////////////////////////////////////

    /////////////////////
    // BRANCH SIGNALS  //
    /////////////////////
    // Branch is only 1 for B and BR
    assign Branch = Opcode[3] & Opcode[2] & ~Opcode[1];

    // Indicates branch is actually taken.
    assign branch_taken = (Branch & actual_taken);

    // It is mispredicted when the predicted taken value doesn't match the actual taken value.
    assign mispredicted = (IF_ID_predicted_taken != actual_taken);

    // A target is miscomputed when the predicted target differs from the actual target.
    assign target_miscomputed = (IF_ID_predicted_target != actual_target);

    // Update BTB whenever the it is a branch and when the target was miscomputed.
    assign wen_BTB = (Branch) & (target_miscomputed);

    // Update BHT on every branch.
    assign wen_BHT = Branch;

    // We update the PC to fetch the actual target when the predictor either predicted incorrectly
    // or when the target was miscomputed and it is a Branch instruction.
    assign update_PC = (mispredicted | target_miscomputed) & (Branch);
    ////////////////////////

    //////////////////
    // ALU SIGNALS  //
    //////////////////
    // The ALU control lines are set to the opcode to allow it to perform the
    // necessary operation for the given instruction
    assign ALUOp = Opcode;

    // ALUSrc must be 1 for SLL, SRA, ROR, LW, SW, LLB, and LHB
    assign ALUSrc = (Opcode[3]) | (Opcode[2] & ~Opcode[1]) | (Opcode[2] & Opcode[1] & ~Opcode[0]);

    // RegSrc must be 1 for LLB and LHB
    assign RegSrc = Opcode[3] & Opcode[1];

    // Z_en is enabled for all ALU instructions except PADDSB and RED.
    assign Z_en = ~Opcode[3] & (~Opcode[1] | ~Opcode[0]);
  
    // NV_en is enabled for just ADD and SUB instructions.
    assign NV_en = Opcode[3:1] == 3'h0;
    ///////////////////

    /////////////////
    // MEM SIGNALS //
    /////////////////
    // MemEnable must be 1 for SW and LW
    assign MemEnable = Opcode[3] & ~Opcode[2] & ~Opcode[1];

    // MemWrite is only 1 for SW
    assign MemWrite = Opcode[3] & ~Opcode[2] & ~Opcode[1] & Opcode[0];
    /////////////////

    /////////////////
    // WB SIGNALS  //
    /////////////////
    // RegWrite must be 1 for ADD, SUB, XOR, RED, SLL, SRA, ROR, PADDSB, LW, LLB, LHB, and PCS
    assign RegWrite = ((~Opcode[3]) | (Opcode[1]) | (Opcode[3] & ~Opcode[2] & ~Opcode[0])) & ~(Opcode[3] & Opcode[2] & Opcode[1] & Opcode[0]);

    // MemtoReg must be 1 for LW instruction
    assign MemtoReg = Opcode[3] & ~Opcode[1];

    // HLT Opcode = 0x1111
    assign HLT = &Opcode;

    // PCS Opcode = 0x1110
    assign PCS = Opcode[3] & Opcode[2] & Opcode[1] & ~Opcode[0];
    ///////////////////////////////////////////////////////////////////////

endmodule

`default_nettype wire  // Reset default behavior at the end
