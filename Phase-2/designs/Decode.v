`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////////////
// Decode.v: Instruction Decode Stage                       //
//                                                          //
// This module implements the instruction decode stage of   //
// the pipeline. It decodes the instruction fetched from    //
// memory and provides control signals for subsequent       //
// stages. It includes logic for determining the target     //
// branch address based on condition codes and also decodes //
// the opcode, registers, and immediate values.             //
//////////////////////////////////////////////////////////////
module Decode (
    input wire clk,                       // System clock
    input wire rst,                       // Active high synchronous reset
    input wire [2:0] flags,               // Flag register signals (ZF, VF, NF)
    input wire IF_ID_predicted_taken,     // Predicted taken signal from the IF/ID stage
    input wire [15:0] pc_inst,            // The current instruction word
    input wire [15:0] pc_next,            // The next instruction's address
    input wire [3:0] MEM_WB_reg_rd,       // Register ID of the destination register (from the MEM/WB stage)
    input wire MEM_WB_RegWrite,           // Write enable to the register file (from the MEM/WB stage)
    input wire [15:0] RegWriteData,       // Data to write to the register file (from the MEM/WB stage)
    
    output wire [62:0] EX_signals,        // Execute stage control signals
    output wire [17:0] MEM_signals,       // Memory stage control signals
    output wire [7:0] WB_signals,         // Write-back stage control signals
    output wire is_branch,                // Indicates a branch instruction
    output wire is_BR,                    // Indicates a branch register instruction
    output wire [15:0] Branch_target,     // Computed branch target address
    output wire taken,                    // Signal used to determine whether branch instruction met condition codes
    output wire misprediction             // Indicates a branch misprediction
  );
  
  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  /////////////////////////// DECODE INSTRUCTION SIGNALS //////////////////////////
  wire [3:0] opcode;        // Opcode of the instruction
  /********************************** REGFILE Signals ******************************/
  wire [3:0] reg_rs;         // Register ID of the first source register extracted from the instruction
  wire [3:0] reg_rt;         // Register ID of the second source register extracted from the instruction
  wire [15:0] SrcReg1_data;  // Data from the first source register
 wire [15:0] SrcReg2_data;   // Data from the second source register
  wire RegSrc;               // Selects register source based on LLB/LHB instructions
  /********************************** ALU Signals **********************************/
  wire [3:0] imm;            // immediate value decoded from the instruction
  wire [15:0] imm_ext;       // Sign-extended or zero-extended immediate from the instruction
  wire [7:0] LB_imm;         // Immediate for LLB/LHB instructions
  /********************************************************************************/
  /////////////////////////// BRANCH CONTROL SIGNALS //////////////////////////////
  wire [8:0] Branch_imm;     // Immediate for branch instructions
  wire [2:0] c_codes;        // Condition codes for branch instructions
  ///////////////////////////// EXECUTE STAGE ////////////////////////////////////
  wire [3:0] SrcReg1;        // Register ID of the first source register
  wire [3:0] SrcReg2;        // Register ID of the second source register
  wire [15:0] ALU_In1;       // First ALU input
  wire [15:0] ALU_imm;       // Immediate for I-type ALU instructions
  wire [15:0] ALU_In2;       // Second ALU input
  wire [3:0] ALUOp;          // ALU operation code
  wire ALUSrc;               // Selects second ALU input (immediate or SrcReg2_data) based on instruction type
  wire Z_en, NV_en;          // Enables setting the Z, N, and V flags
  /////////////////////////// MEMORY STAGE ///////////////////////////////////////
  wire [15:0] MemWriteData;  // Data written to the data memory for SW
  wire MemEnable;            // Enables reading from memory
  wire MemWrite;             // Enables writing to memory
  /////////////////////////// WRITE BACK STAGE ///////////////////////////////////
  wire [3:0] reg_rd;         // Register ID of the destination register
  wire RegWrite;             // Enables writing to the register file
  wire MemToReg;             // Selects data to write back to the register file        
  wire HLT;                  // Indicates a HLT instruction
  wire PCS;                  // Indicates a PCS instruction
  ////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////
  // Decode control signals from the opcode   //
  //////////////////////////////////////////////
  // Get the opcode from the instructions.
  assign opcode = pc_inst[15:12];

  // We detect a misprediction if the prediction from the fetch stage differs from the decode stage.
  assign misprediction = taken != IF_ID_predicted_taken;

  // Instantiate the Control Unit.
  ControlUnit iCC (
      .Opcode(opcode),
      .ALUSrc(ALUSrc),
      .MemtoReg(MemToReg),
      .RegWrite(RegWrite),
      .RegSrc(RegSrc),
      .MemEnable(MemEnable),
      .MemWrite(MemWrite),
      .Branch(is_branch),
      .HLT(HLT),
      .PCS(PCS),
      .ALUOp(ALUOp),
      .Z_en(Z_en),
      .NV_en(NV_en)
  );
  //////////////////////////////////////////////

  ////////////////////////////////////////////////////////////
  // Package each stage's control signals for the pipeline  //
  ////////////////////////////////////////////////////////////
  // Package the execute stage control signals.
  assign EX_signals = {SrcReg1, SrcReg2, ALU_In1, ALU_imm, ALU_In2, ALUOp, ALUSrc, Z_en, NV_en};

  // Package the memory stage control signals.
  assign MEM_signals = {MemWriteData, MemEnable, MemWrite};

  // Package the write back stage control signals.
  assign WB_signals = {reg_rd, RegWrite, MemToReg, HLT, PCS};
  /////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////
  // Determine the branch target address and whether branch is taken  //
  //////////////////////////////////////////////////////////////////////
  // Get the 9-bit right shifted branch target offset.
  assign Branch_imm = pc_inst[8:0];
  
  // Indicates the branch is a BR instruction.
  assign is_BR = pc_inst[12];

  // Get the condition codes to determine if branch is taken or not.
  assign c_codes = pc_inst[11:9];

  // Instantiate the Branch Control Unit.
  Branch_control iBC (
      .C(c_codes),
      .I(Branch_imm),
      .F(flags),
      .Rs(SrcReg1_data),
      .BR(is_BR),
      .PC_next(pc_next),
      .taken(taken),
      .PC_branch(Branch_target)
  );
  ////////////////////////////////////////////////////////////////////////

  //////////////////////////////
  // Access the Register File //
  //////////////////////////////
  // Extract the register id's from the instruction word.
  assign reg_rd = pc_inst[11:8]; // destination register id
  assign reg_rs = pc_inst[7:4];  // first source register id
  assign reg_rt = pc_inst[3:0];  // second source register id

  // Get the immediate value for I-type instructions.
  assign imm = pc_inst[3:0];
  assign LB_imm = pc_inst[7:0];

  // Select the source register for ALU operations.
  assign SrcReg1 = (RegSrc) ? reg_rd : reg_rs;
  assign SrcReg2 = (MemWrite) ? reg_rd : reg_rt;

  // Get the memory write data as coming from the second read register.
  assign MemWriteData = SrcReg2_data;
  
  // Instantiate the register file.
  RegisterFile iRF (
      .clk(clk),
      .rst(rst),
      .SrcReg1(SrcReg1),
      .SrcReg2(SrcReg2),
      .DstReg(MEM_WB_reg_rd),
      .WriteReg(MEM_WB_RegWrite),
      .DstData(RegWriteData),
      .SrcData1(SrcReg1_data),
      .SrcData2(SrcReg2_data)
  );
  ////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////
  // Determine the ALU input operands  //
  ///////////////////////////////////////
  // Sign-extend or zero-extend the immediate from the instruction based on memory vs non-memory instructions.
  assign imm_ext = (MemEnable) ? {{12{imm[3]}}, imm} : {12'h000, imm};

  // Grab the LLB/LHB immediate or the extended immediate based on the instruction as the ALU immediate.
  assign ALU_imm = (RegSrc) ? {8'h00, LB_imm} : imm_ext;
  
  // Get the first ALU input as the first register read out.
  assign ALU_In1 = SrcReg1_data;

  // Determine the 2nd ALU input, either immediate or SrcReg2 data (Rd for save word or Rt otherwise).
  assign ALU_In2 = (ALUSrc) ? ALU_imm : SrcReg2_data;
  /////////////////////////////////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end