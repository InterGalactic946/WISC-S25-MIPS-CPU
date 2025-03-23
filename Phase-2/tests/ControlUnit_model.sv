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
          4'b0000, 4'b0001: begin  // ADD, SUB (opcode 0, 1, 2, 3, 7)
            Z_en = 1'b1;           // Z flag enable
            NV_en = 1'b1;          // N/V flag enable
          end
          4'b0010: begin      // XOR (opcode 2)
              Z_en = 1'b1;    // Z flag enable
          end
          4'b0100, 4'b0101, 4'b0110: begin  // SLL, SRA, ROR (opcode 4, 5, 6)
              ALUSrc = 1'b1;                // ALUSrc is 1 for shift operations
              Z_en = 1'b1;                  // Z flag enable
          end
          4'b0111: begin // PADDSB (opcode 7)
            // Has all the default values.
          end
          4'b1000: begin  // LW (opcode 8)
              ALUSrc = 1'b1;     // ALUSrc is 1 for LW
              MemtoReg = 1'b1;   // Memory to register operation
              MemEnable = 1'b1;  // Memory enable
          end
          4'b1001: begin  // SW (opcode 9)
              ALUSrc = 1'b1;    // ALUSrc is 1 for SW
              MemtoReg = 1'b0;  // MemtoReg is x for SW operations
              RegWrite = 1'b0;  // No register write
              MemEnable = 1'b1; // Memory enable
              MemWrite = 1'b1;  // Memory write operation
          end
          4'b1010, 4'b1011: begin  // LLB, LHB (opcode 10, 11)
              ALUSrc = 1'b1;       // ALUSrc is 1 for LW
              RegSrc = 1'b1;       // Register source for LLB/LHB
          end
          4'b1100, 4'b1101: begin  // Branch (B, BR) instructions
            ALUSrc = 1'b0;       // ALUSrc is  a don't care for B instructions
            MemtoReg = 1'b0;     // MemtoReg is x for B operations
            RegWrite = 1'b0;     // No register write
            Branch = 1'b1;       // Branch operation
            RegSrc = 1'b0;       // Register source is x for B operations

            // Branch is taken.
            branch_taken = actual_taken;
            
            // It is mispredicted when the prev instruction is different from actual taken.
            mispredicted = (IF_ID_predicted_taken !== actual_taken);

            // A target is miscomputed when the predicted target differs from the actual target.
            target_miscomputed = (IF_ID_predicted_target !== actual_target);

            // Update BTB whenever the it is a branch and it is actually taken or when the target was miscomputed.
            wen_BTB = ((actual_taken) || (target_miscomputed));

            // Update BHT on a mispredicted branch instruction.
            wen_BHT = mispredicted;

            // We update the PC to fetch the actual target when the predictor either predicted incorrectly
            // or when the target was miscomputed and the branch was actually taken.
            update_PC = (mispredicted || target_miscomputed) && (branch_taken);
          end
          4'b1110: begin  // PCS instruction (opcode 14)
              ALUSrc = 1'b0;    // ALUSrc is a don't care for PCS operation
              RegSrc = 1'b0;    // RegSrc is a don't care for PCS
              PCS = 1'b1;       // PCS operation
          end
          4'b1111: begin  // HLT instruction (opcode 15)
              HLT = 1'b1;      // HLT operation
              ALUSrc = 1'b0;   // ALUSrc is 0 for HLT operations
              MemtoReg = 1'b0; // MemtoReg is 0 for HLT operations
              RegWrite = 1'b0; // Register write is 0 for HLT
              MemEnable = 1'b0;// Memory enable is off for HLT
              MemWrite = 1'b0; // No memory write for HLT
              Branch = 1'b0;   // No branch for HLT
              RegSrc = 1'b0;   // Register source is 0 for HLT
          end
          default: begin
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
    ///////////////////////////////////////////////////////////////////////

endmodule