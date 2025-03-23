///////////////////////////////////////////////////////////
// ControlUnit_model.sv: Model Control Unit Module       //  
//                                                       //
// This module models the control signals for the model  //
// CPU.                                                  //
///////////////////////////////////////////////////////////
module ControlUnit_model (
    input logic [3:0] Opcode,                  // Opcode of the current instruction
    input logic actual_taken,                  // Indicates if the branch was actually taken
    input logic IF_ID_predicted_taken,         // Predicted taken value from the branch predictor
    input logic [15:0] IF_ID_predicted_target, // Predicted target address from the branch predictor of the previous instruction
    input logic [15:0] actual_target,          // Actual target address computed by the ALU
    
    output logic Branch,                       // Used to signal that the PC fetched a branch instruction
    output logic wen_BTB,                      // Write enable for BTB (Branch Target Buffer)
    output logic wen_BHT,                      // Write enable for BHT (Branch History Table)
    output logic update_PC,                    // Signal to update the PC with the actual target

    output logic [3:0] ALUOp,                  // Control lines into the ALU to allow for the unit to determine its operation
    output logic ALUSrc,                       // Determines whether to use the immediate or register-value as the ALU input
    output logic RegSrc,                       // Determines if the read register port 1 should use rs or rd, which is read from for LLB/LHB operations
    output logic Z_en,                         // Signal to turn on the Z flag registers
    output logic NV_en,                        // Signal to turn on the N and V flag registers
    
    output logic MemEnable,                    // Looks for whether the memory unit is used in this operation
    output logic MemWrite,                     // Looks for whether the memory unit is written to in this operation

    output logic RegWrite,                     // Determines if the register file is being written to
    output logic MemtoReg,                     // Allows for choosing between writing from the ALU or memory output to the register file
    output logic HLT,                          // Used to signal an HLT instruction
    output logic PCS                          // Used to signal a PCS instruction
);

    /////////////////////////////////////////////////
    // Declare any internal signals as type wire  //
    ///////////////////////////////////////////////
    logic mispredicted;        // Indicates previous instruction's fetch mispredicted.
    logic target_miscomputed;  // Indicates previous instruction's fetch miscomputed the target.
    logic branch_taken;        // Indicates branch was actually taken.
    ////////////////////////////////////////////////

    //////////////////////////////////////////////////////
    // Generate control signals by decoding the opcode //
    ////////////////////////////////////////////////////
    always_comb begin
        // Default values
        ALUSrc = 1'b0;   
        MemtoReg = 1'b0;
        RegWrite = 1'b1; 
        MemEnable = 1'b0;
        MemWrite = 1'b0; 
        Branch = 1'b0; 
        RegSrc = 1'b0;  
        PCS = 1'b0;    
        HLT = 1'b0;     
        ALUOp = Opcode;
        Z_en = 1'b0;    
        NV_en = 1'b0; 
        branch_taken = 1'b0;
        mispredicted = 1'b0;
        target_miscomputed = 1'b0;
        wen_BTB = 1'b0;
        wen_BHT = 1'b0;
        update_PC = 1'b0;

        // Decode the control signals based on the opcode.
        case (Opcode)
            4'b0000, 4'b0001: begin  // ADD, SUB
                Z_en = 1'b1;     // Zero flag enable
                NV_en = 1'b1;    // Negative/Overflow flag enable
            end
            4'b0010: begin  // XOR
                Z_en = 1'b1;    // Zero flag enable
            end
            4'b0100, 4'b0101, 4'b0110: begin  // SLL, SRA, ROR
                ALUSrc = 1'b1;  // Shift operations use immediate shift amount
                Z_en = 1'b1;    // Zero flag enable
            end
            4'b0111: begin  // PADDSB
                // Default values apply.
            end
            4'b1000: begin  // LW
                ALUSrc = 1'b1;     // Load word uses immediate offset
                MemtoReg = 1'b1;   // Memory to register
                MemEnable = 1'b1;  // Enable memory read
            end
            4'b1001: begin  // SW
                ALUSrc = 1'b1;    // Store word uses immediate offset
                RegWrite = 1'b0;  // No register write
                MemEnable = 1'b1; // Enable memory access
                MemWrite = 1'b1;  // Memory write operation
            end
            4'b1010, 4'b1011: begin  // LLB, LHB
                ALUSrc = 1'b1;   // Immediate used for upper/lower byte load
                RegSrc = 1'b1;   // Source is immediate-based
            end
            4'b1100, 4'b1101: begin  // Branch (B, BR)
                Branch = 1'b1;

                // Determine if branch is taken
                branch_taken = actual_taken;

                // Detect misprediction
                mispredicted = (IF_ID_predicted_taken !== actual_taken);

                // Detect miscomputed target
                target_miscomputed = (IF_ID_predicted_target !== actual_target);

                // Update BTB if branch was actually taken or if target was miscomputed
                wen_BTB = actual_taken || target_miscomputed;

                // Update BHT if branch was mispredicted
                wen_BHT = mispredicted;

                // Update PC if misprediction or miscomputed target occurs
                update_PC = (mispredicted || target_miscomputed) && branch_taken;
            end
            4'b1110: begin  // PCS
                PCS = 1'b1;   // Enable PCS operation
            end
            4'b1111: begin  // HLT
                HLT = 1'b1;    // Halt execution
                RegWrite = 1'b0;
            end
            default: begin
                // Already handled by default values.
            end
        endcase
    end
    ///////////////////////////////////////////////////////////////////////

endmodule