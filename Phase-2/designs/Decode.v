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
    input wire [15:0] pc_inst,            // The current instruction word
    input wire [15:0] pc_next,            // The next instruction's address
    input wire [3:0] MEM_WB_reg_rd,       // Register ID of the destination register (from the MEM/WB stage)
    input wire MEM_WB_RegWrite,           // Write enable to the register file (from the MEM/WB stage)
    input wire [15:0] RegWriteData,       // Data to write to the register file (from the MEM/WB stage)
    
    output wire [37:0] EX_signals,        // Execute stage control signals
    output wire [17:0] MEM_signals,       // Memory stage control signals
    output wire [7:0] WB_signals,         // Write-back stage control signals
    output wire [15:0] Branch_target,     // Computed branch target address
    output wire Branch_taken              // Signal used to determine whether branch is taken
  );
  
  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  /////////////////////////// DECODE INSTRUCTION SIGNALS //////////////////////////
  wire [3:0] opcode;        // Opcode of the instruction
  /********************************** REGFILE Signals ******************************/
  wire [3:0] reg_rs;         // Register ID of the first source register
  wire [3:0] reg_rt;         // Register ID of the second source register
  wire [3:0] SrcReg1;        // Register ID of the first source register
  wire [3:0] SrcReg2;        // Register ID of the second source register
  wire [15:0] SrcReg1_data;  // Data from the first source register
  wire [15:0] SrcReg2_data;  // Data from the second source register
  wire RegSrc;               // Selects register source based on LLB/LHB instructions
  /********************************** ALU Signals **********************************/
  wire [3:0] ALU_imm;        // Immediate for ALU instructions (SLL/SRA/ROR)
  wire [15:0] imm;           // Sign extended immediate value for ALU operations
  wire ALUSrc;               // Selects second ALU input based on instruction type
  wire [15:0] ALU_In2_step;  // Second ALU input based on the instruction type
  wire [3:0] Mem_offset;     // Offset for memory instructions (LW/SW)
  wire [15:0] Mem_ex_offset; // Sign extended memory offset
  wire [7:0] LB_imm;         // Immediate for LLB/LHB instructions
  /********************************************************************************/
  /////////////////////////// BRANCH CONTROL SIGNALS //////////////////////////////
  wire [8:0] Branch_imm;     // Immediate for branch instructions
  wire [2:0] c_codes;        // Condition codes for branch instructions
  wire Branch;               // Indicates a branch instruction
  ///////////////////////////// EXECUTE STAGE ////////////////////////////////////
  wire [15:0] ALU_In1;       // First ALU input
  wire [15:0] ALU_In2;       // Second ALU input
  wire [3:0] ALUOp;          // ALU operation code
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

  // Instantiate the Control Unit.
  ControlUnit iCC (
      .Opcode(opcode),
      .ALUSrc(ALUSrc),
      .MemtoReg(MemToReg),
      .RegWrite(RegWrite),
      .RegSrc(RegSrc),
      .MemEnable(MemEnable),
      .MemWrite(MemWrite),
      .Branch(Branch),
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
  assign EX_signals = {ALU_In1, ALU_In2, ALUOp, Z_en, NV_en};

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

  // Get the condition codes to determine if branch is taken or not.
  assign c_codes = pc_inst[11:9];

  // Instantiate the Branch Control Unit.
  Branch_control iBC (
      .C(c_codes),
      .I(Branch_imm),
      .F(flags),
      .Rs(SrcReg1_data),
      .Branch(Branch),
      .BR(pc_inst[12]),
      .PC_next(pc_next),
      .Branch_taken(Branch_taken),
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
  // Get the immediate value for SLL/SRA/ROR/MEM/Branch instructions along with condition codes.
  assign ALU_imm = pc_inst[3:0];
  assign Mem_offset = pc_inst[3:0];
  assign LB_imm = pc_inst[7:0];

  // Grab the LLB/LHB immediate or the ALU immediate based on the instruction.
  assign imm = (RegSrc) ? {8'h00, LB_imm} : {12'h000, ALU_imm};

  // Determine the 2nd ALU input, either zero-extended immediate or SrcReg2 data (Rd for save word or Rt otherwise).
  assign ALU_In2_step = (ALUSrc) ? imm : SrcReg2_data;

  // Sign extend the immediate memory offset.
  assign Mem_ex_offset = {{12{Mem_offset[3]}}, Mem_offset};
  
  // Get the first ALU input as the first register read out.
  assign ALU_In1 = SrcReg1_data;

  // Get the second ALU input based on whether it is LW/SW instruction or not.
  assign ALU_In2 = (MemEnable) ? Mem_ex_offset : ALU_In2_step;
  /////////////////////////////////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end