default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////////
// HazardDetectionUnit.v: Handle stall conditions for Branch //
// Instructions (B, BR) and load-to-use hazards.             //
//                                                           //
// This module detects hazards in the pipeline and applies   //
// necessary stalls for both branch and load instructions.   //
///////////////////////////////////////////////////////////////
module HazardDetectionUnit (
    input wire [3:0] ID_EX_reg_rd,     // Destination register ID in ID/EX stage
    input wire [3:0] EX_MEM_reg_rd,    // Destination register ID in EX/MEM stage
    input wire [3:0] SrcReg1,          // First source register ID (Rs) in ID stage
    input wire [3:0] SrcReg2,          // Second source register ID (Rt) in ID stage
    input wire ID_EX_RegWrite,         // Register write signal from ID/EX stage
    input wire EX_MEM_RegWrite,        // Register write signal from EX/MEM stage
    input wire ID_EX_MemEnable,        // Data memory enable signal from ID/EX stage
    input wire ID_EX_MemWrite,         // Data memory write signal from ID/EX stage
    input wire MemWrite,               // Memory write signal for current instruction
    input wire Branch,                 // Branch signal indicating a branch instruction
    input wire ID_EX_Z_en,             // Zero flag enable signal from ID/EX stage
    input wire ID_EX_NV_en,            // Negative/Overflow flag enable signal from ID/EX stage
    input wire branch_mispredicted,    // Signal indicating branch misprediction
    input wire branch_taken            // Signal indicating branch is taken
    
    output wire PC_stall,              // Stall signal for IF stage
    output wire IF_ID_stall,           // Stall signal for ID stage
    output wire ID_flush,              // Flush signal for ID/EX register
    output wire IF_flush               // Flush signal for IF/ID register
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire ID_EX_MemRead;      // Indicates instruction in the EX stage is a LW instruction
  wire load_to_use_hazard; // Signal to detect and place a load-to-use stall in the pipeline
  wire B_hazard;           // Detects a hazard for B type branch instructions
  wire EX_to_ID_haz_BR;    // Detects a hazard between the beginning of the EX and ID stage for BR instructions
  wire MEM_to_ID_haz_BR;   // Detects a hazard between the beginning of the MEM and ID stage for BR instructions
  wire BR_hazard;          // Detects a hazard for BR type branch instructions
  ////////////////////////////////////////////////

  /////////////////////////////////////////////////////
  // Stall conditions for LW, B, and BR instructions //
  /////////////////////////////////////////////////////
  // We stall anytime there is a branch or load to use hazard in the fetch and decode stages.
  assign PC_stall = load_to_use_hazard | B_hazard | BR_hazard;
  assign IF_ID_stall = load_to_use_hazard | B_hazard | BR_hazard;
  /////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////
  // Flush the pipeline on load to use or branch misprediction //
  ///////////////////////////////////////////////////////////////
  // We flush the ID_EX pipeline register and send nops during a load to use stall.
  assign ID_flush = load_to_use_hazard;

  // We flush the IF_ID pipeline instruction word whenever we predict the branch incorrectly and
  // it is taken.
  assign IF_flush = branch_mispredicted & branch_taken;
  /////////////////////////////////////////////////////////////

  //////////////////////////////////
  // Load-to-Use Hazard Detection //
  //////////////////////////////////
  // We are reading from memory in the ID/EX stage if data memory is enabled and we are not writing to it (LW).
  assign ID_EX_MemRead = ID_EX_MemEnable & ~ID_EX_MemWrite;
  
  // A load to use hazard is detected when the instruction in the EX stage (LW) is writing to the same register that the instruction 
  // in the decode stage is trying to read. We don't want to stall when the second read register is the same and
  // is a save word, as we have MEM-MEM forwarding available.
  assign load_to_use_hazard = (ID_EX_MemRead & (ID_EX_reg_rd != 0) & ((ID_EX_reg_rd == SrcReg1) | ((ID_EX_reg_rd == SrcReg2) & ~MemWrite)));
  ////////////////////////////////////

  /////////////////////////////
  // Branch Hazard Detection //
  /////////////////////////////    
  // Indicates the previous instruction in the EX stage is writing to the same register (not $0) as the BR
  // instruction needs in the ID stage (Rs), so we need to stall.
  assign EX_to_ID_haz_BR = (EX_MEM_RegWrite & (EX_MEM_reg_rd != 4'h0)) & (EX_MEM_reg_rd == SrcReg1);

  // Indicates the previous instruction in the MEM stage is writing to the same register (not $0) as the BR
  // instruction needs in the ID stage (Rs), so we need to stall.
  assign MEM_to_ID_haz_BR = (ID_EX_RegWrite & (ID_EX_reg_rd != 4'h0)) & (ID_EX_reg_rd == SrcReg1);

  // There is a hazard for the B instruction when it is in the decode stage and 
  // a flag setting ALU instruction is in the EX stage.
  assign B_hazard = (Branch) & (ID_EX_Z_en | ID_EX_NV_en);

  // We have a BR hazard if it is a B hazard (for condition codes) and either when EX-to-ID or MEM-to-ID hazards exist.
  assign BR_hazard = (B_hazard) & (EX_to_ID_haz_BR | MEM_to_ID_haz_BR);
  ////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end
