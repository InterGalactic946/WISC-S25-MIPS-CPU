`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////////
// HazardDetectionUnit.v: Handle stall conditions for Branch //
// Instructions (B, BR) and load-to-use hazards.             //
//                                                           //
// This module detects hazards in the pipeline and applies   //
// necessary stalls for both branch and load instructions.   //
///////////////////////////////////////////////////////////////
module HazardDetectionUnit (
    input wire [3:0] SrcReg1,          // First source register ID (Rs) in ID stage
    input wire [3:0] SrcReg2,          // Second source register ID (Rt) in ID stage
    input wire ID_EX_RegWrite,         // Register write signal from ID/EX stage
    input wire [3:0] ID_EX_reg_rd,     // Destination register ID in ID/EX stage
    input wire [3:0] EX_MEM_reg_rd,    // Destination register ID in EX/MEM stage
    input wire EX_MEM_RegWrite,        // Register write signal from EX/MEM stage
    input wire ID_EX_MemEnable,        // Data memory enable signal from ID/EX stage
    input wire ID_EX_MemWrite,         // Data memory write signal from ID/EX stage
    input wire MemWrite,               // Memory write signal for current instruction
    input wire ID_EX_Z_en,             // Zero flag enable signal from ID/EX stage
    input wire ID_EX_NV_en,            // Negative/Overflow flag enable signal from ID/EX stage
    input wire Branch,                 // Branch signal indicating a branch instruction
    input wire BR,                     // BR signal indicating a BR instruction
    input wire ICACHE_miss,            // Signal indicating that the instruction cache had a miss so PC must stall and NOP inserted into IF_ID
    input wire DCACHE_miss,            // Signal indicating that the data cache had a miss so whole pipeline must stall and NOP inserted into MEM_WB
    input wire update_PC,              // Signal that we need to update the PC
    
    output wire PC_stall,              // Stall signal for IF stage
    output wire IF_ID_stall,           // Stall signal for ID stage
    output wire ID_EX_stall,           // Stall signal for EX stage
    output wire EX_MEM_stall,          // Stall signal for MEM stage
    output wire MEM_flush,             // Flush signal for EX/MEM register
    output wire ID_flush,              // Flush signal for ID/EX register
    output wire IF_flush               // Flush signal for IF/ID register
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire ID_EX_MemRead;      // Indicates instruction in the EX stage is a LW instruction
  wire load_to_use_hazard; // Signal to detect and place a load-to-use stall in the pipeline
  wire B_hazard;           // Detects a hazard for B type branch instructions
  wire BR_inst;            // Indicates a BR instruction.
  wire EX_to_ID_haz_BR;    // Detects a hazard between the beginning of the EX and ID stage for BR instructions
  wire MEM_to_ID_haz_BR;   // Detects a hazard between the beginning of the MEM and ID stage for BR instructions
  wire BR_hazard;          // Detects a hazard for BR type branch instructions
  ////////////////////////////////////////////////

  ////////////////////////////////////////////////////////
  // Stall conditions for LW/SW, B, and BR instructions //
  ////////////////////////////////////////////////////////
  // We stall PC whenever we stall the IF_ID pipeline register or when the ICACHE is busy.
  assign PC_stall = ICACHE_miss | IF_ID_stall;

  // We stall anytime we stall on EX_MEM or when there is a branch or load to use hazard in the decode stage.
  assign IF_ID_stall = EX_MEM_stall | load_to_use_hazard | B_hazard | BR_hazard;

  // We stall anytime we stall the EX_MEM pipeline register.
  assign ID_EX_stall = EX_MEM_stall;

  // We stall anytime the DCACHE had a miss.
  assign EX_MEM_stall = DCACHE_miss;
  /////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////
  // Flush the pipeline on memory accesses or branch misprediction //
  ///////////////////////////////////////////////////////////////////
  // We flush the MEM_WB pipeline register whenever the DCACHE had a miss.
  assign MEM_flush = DCACHE_miss;
  
  // We flush the ID_EX pipeline register when not stalling on execute and whenever there is a branch or load to use hazard, i.e. send nops to execute onward.
  assign ID_flush = (~ID_EX_stall) & (load_to_use_hazard | B_hazard | BR_hazard);

  // We flush the IF_ID pipeline instruction word whenever we are when not stalling on decode and stalling on PC, i.e. on an ICACHE miss, or need to update the PC, i.e. on an incorrect branch fetch.
  assign IF_flush = (~IF_ID_stall) & (ICACHE_miss | update_PC);
  /////////////////////////////////////////////////////////////

  //////////////////////////////////
  // Load-to-Use Hazard Detection //
  //////////////////////////////////
  // We are reading from memory in the ID/EX stage if data memory is enabled and we are not writing to it (LW).
  assign ID_EX_MemRead = ID_EX_MemEnable & ~ID_EX_MemWrite;
  
  // A load to use hazard is detected when the instruction in the EX stage (LW) is writing to the same register that the instruction 
  // in the decode stage is trying to read. We don't want to stall when the second read register is the same and
  // is a save word instruction, as we have MEM-MEM forwarding available.
  assign load_to_use_hazard = (ID_EX_MemRead & (ID_EX_reg_rd != 4'h0) & ((ID_EX_reg_rd == SrcReg1) | ((ID_EX_reg_rd == SrcReg2) & ~MemWrite)));
  ////////////////////////////////////

  /////////////////////////////
  // Branch Hazard Detection //
  /////////////////////////////
  // Indicates the previous instruction in the EX stage is writing to the same register (not $0) 
  // as the BR instruction needs in the ID stage (Rs), so we need to stall.
  assign EX_to_ID_haz_BR = (ID_EX_RegWrite & (ID_EX_reg_rd != 4'h0)) & (ID_EX_reg_rd == SrcReg1);    

  // Indicates the previous instruction in the MEM stage is writing to the same register (not $0) 
  // as the BR instruction needs in the ID stage (Rs), so we need to stall.
  assign MEM_to_ID_haz_BR = (EX_MEM_RegWrite & (EX_MEM_reg_rd != 4'h0)) & (EX_MEM_reg_rd == SrcReg1);

  // There is a hazard for the B instruction when it is in the decode stage and 
  // a flag setting ALU instruction is in the EX stage.
  assign B_hazard = (Branch) & (ID_EX_Z_en | ID_EX_NV_en);

  // Indicates a BR instruction.
  assign BR_inst = Branch & BR;

  // We have a BR hazard if it is a BR instruction and is a B type hazard (for condition codes) or either when EX-to-ID or MEM-to-ID hazards exist.
  assign BR_hazard = (BR_inst) & ((ID_EX_Z_en | ID_EX_NV_en) | EX_to_ID_haz_BR | MEM_to_ID_haz_BR);
  ////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end
