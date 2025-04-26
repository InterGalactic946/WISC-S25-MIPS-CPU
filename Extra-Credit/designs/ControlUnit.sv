///////////////////////////////////////////////////////////
// ControlUnit_model.sv: Control Unit Module            //
//                                                       //
// This module generates control signals for the CPU,   //
// including branch prediction, ALU operations, memory, //
// and register operations. It decodes the opcode and   //
// determines the required control signals for each     //
// instruction type.                                    //
///////////////////////////////////////////////////////////

module ControlUnit (
    input logic [3:0] Opcode,                  // Opcode of the current instruction
    
    output logic Branch,                       // Indicates if the current instruction is a branch

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

    logic error; // Error signal.
    
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
        error = 1'b0; // Default no error state.

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

                RegWrite = 1'b0; // No register write for branch instructions
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
                error = 1'b1; // Default error state.
            end
        endcase
    end
    ////////////////////////////////////////////////////////////

endmodule
