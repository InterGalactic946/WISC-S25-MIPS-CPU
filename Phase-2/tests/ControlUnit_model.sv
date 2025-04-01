///////////////////////////////////////////////////////////
// ControlUnit_model.sv: Control Unit Module            //
//                                                       //
// This module generates control signals for the CPU,   //
// including branch prediction, ALU operations, memory, //
// and register operations. It decodes the opcode and   //
// determines the required control signals for each     //
// instruction type.                                    //
///////////////////////////////////////////////////////////

module ControlUnit_model (
    input logic [3:0] Opcode,                  // Opcode of the current instruction
    input logic actual_taken,                  // Indicates if the branch was actually taken
    input logic IF_ID_predicted_taken,         // Predicted taken value from the branch predictor
    input logic [15:0] IF_ID_predicted_target, // Predicted target address from the branch predictor of the previous instruction
    input logic [15:0] actual_target,          // Actual target address computed by the ALU
    
    output logic Branch,                       // Indicates if the current instruction is a branch
    output logic wen_BTB,                      // Write enable for Branch Target Buffer (BTB)
    output logic wen_BHT,                      // Write enable for Branch History Table (BHT)
    output logic update_PC,                    // Signal to update the PC with the actual target

    output logic [3:0] ALUOp,                  // Control lines for the ALU to determine its operation
    output logic ALUSrc,                       // Determines if the ALU uses an immediate or register value
    output logic RegSrc,                       // Determines if the read register port 1 uses rs or rd
    output logic Z_en,                         // Signal to enable the Zero flag register
    output logic NV_en,                        // Signal to enable Negative and Overflow flag registers
    
    output logic MemEnable,                    // Indicates if the memory unit is used in this operation
    output logic MemWrite,                     // Indicates if memory is written to in this operation

    output logic RegWrite,                     // Indicates if the register file is written to
    output logic MemtoReg,                     // Chooses between writing from ALU or memory to the register file
    output logic HLT,                          // Signal to halt the execution
    output logic PCS                          // Signal to indicate a PCS (Program Counter Shift)
);

    /////////////////////////////////////////////////
    // Internal signals to track branch and target //
    /////////////////////////////////////////////////
    logic mispredicted;        // Indicates if the previous instruction was mispredicted
    logic target_miscomputed;  // Indicates if the target address was miscomputed
    logic branch_taken;        // Indicates if the branch was actually taken
    ////////////////////////////////////////////////

    ///////////////////////////////////////////////////////
    // Generate control signals by decoding the opcode //
    ///////////////////////////////////////////////////////
    always_comb begin
        // Default values for all control signals
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

        // Decode control signals based on the opcode
        case (Opcode)
            4'b0000, 4'b0001: begin  // ADD, SUB
                Z_en = 1'b1;     // Enable Zero flag
                NV_en = 1'b1;    // Enable Negative and Overflow flags
            end
            4'b0010: begin  // XOR
                Z_en = 1'b1;    // Enable Zero flag
            end
            4'b0100, 4'b0101, 4'b0110: begin  // SLL, SRA, ROR
                ALUSrc = 1'b1;  // Use immediate value for shift amount
                Z_en = 1'b1;    // Enable Zero flag
            end
            4'b0111: begin  // PADDSB
                // No additional control signals needed for PADDSB
            end
            4'b1000: begin  // LW (Load Word)
                ALUSrc = 1'b1;     // Use immediate offset for address calculation
                MemtoReg = 1'b1;   // Load data from memory to register
                MemEnable = 1'b1;  // Enable memory read operation
            end
            4'b1001: begin  // SW (Store Word)
                ALUSrc = 1'b1;    // Use immediate offset for address calculation
                RegWrite = 1'b0;  // No register write for store instruction
                MemEnable = 1'b1; // Enable memory access
                MemtoReg = 1'b1;  // Dont care about the output
                MemWrite = 1'b1;  // Perform memory write
            end
            4'b1010, 4'b1011: begin  // LLB, LHB (Load Lower Byte, Load Higher Byte)
                ALUSrc = 1'b1;   // Use immediate for address computation
                RegSrc = 1'b1;   // Use immediate as the destination register
            end
            4'b1100, 4'b1101: begin  // Branch (B, BR)
                Branch = 1'b1;   // Indicate a branch instruction
                branch_taken = actual_taken && Branch;  // Set branch_taken signal based on actual branch outcome

                RegWrite = 1'b0; // No register write for branch instructions

                // Check if there was a branch misprediction
                mispredicted = (IF_ID_predicted_taken !== actual_taken);

                // Check if there was a miscomputed target address
                target_miscomputed = (IF_ID_predicted_target !== actual_target);

                // Write to BTB if it was branch and if target address was miscomputed
                wen_BTB = (target_miscomputed) && Branch;

                // Write to BHT for every branch instruction
                wen_BHT = Branch;

                // Update PC if misprediction or miscomputed target occurred
                update_PC = (mispredicted || target_miscomputed) && Branch;
            end
            4'b1110: begin  // PCS (Program Counter Shift)
                PCS = 1'b1;   // Enable PCS operation
            end
            4'b1111: begin  // HLT (Halt)
                HLT = 1'b1;    // Halt the execution
                RegWrite = 1'b0;  // No register write after halt
            end
            default: begin
                // Default behavior: setting all control signals to their initial values
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
            end
        endcase
    end
    ////////////////////////////////////////////////////////////

endmodule
