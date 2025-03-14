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
module Decode(clk, rst, ZF, VF, NF, pc_inst, pc_next, 
              RegSrc, RegWrite, Branch, ALUSrc, ALUOp, 
              Z_en, NV_en, MemEnable, MemWrite, MemToReg, HLT, PCS, 
              Branch_target, Branch_taken, SrcReg1, SrcReg2, 
              SrcReg1_data, SrcReg2_data, 
              opcode, reg_rd, reg_rs, reg_rt, 
              ALU_imm, Mem_offset, LB_imm, Branch_imm, c_codes);

  input wire clk;             // System clock
  input wire rst;             // Active high synchronous reset
  input wire ZF, VF, NF;      // Flag register signals
  input wire [15:0] pc_inst;  // The current instruction word
  input wire [15:0] pc_next;  // The next instruction's address

  /////////////////////////// DECODE INSTRUCTION SIGNALS ////////////////////////////
  output wire [3:0] opcode;        // Opcode of the instruction
  output wire [3:0] reg_rd;        // Register ID of the destination register
  output wire [3:0] reg_rs;        // Register ID of the first source register
  output wire [3:0] reg_rt;        // Register ID of the second source register
  output wire [3:0] ALU_imm;       // Immediate for ALU instructions (SLL/SRA/ROR)
  output wire [3:0] Mem_offset;    // Offset for memory instructions (LW/SW)
  output wire [7:0] LB_imm;        // Immediate for LLB/LHB instructions
  output wire [8:0] Branch_imm;    // Immediate for branch instructions
  output wire [2:0] c_codes;       // Condition codes for branch instructions
  ///////////////////////////// CONTROL UNIT SIGNALS ///////////////////////////////
  output wire RegSrc;              // Selects register source based on LLB/LHB instructions
  output wire RegWrite;            // Enables writing to the register file        
  output wire Branch;              // Indicates a branch instruction
  output wire ALUSrc;              // Selects second ALU input based on instruction type
  output wire [3:0] ALUOp;         // ALU operation code
  output wire Z_en, NV_en;         // Enables setting the Z, N, and V flags
  output wire MemWrite;            // Enables writing to memory
  output wire MemEnable;           // Enables reading from memory
  output wire MemToReg;            // Selects data to write back to the register file
  output wire HLT;                 // Indicates a HLT instruction
  output wire PCS;                 // Indicates a PCS instruction
  ////////////////////////// BRANCH CONTROL UNIT SIGNALS ///////////////////////////
  output wire [15:0] Branch_target; // Computed branch target address
  output wire Branch_taken;         // Signal used to determine whether branch is taken
  /////////////////////////// EXECUTE STAGE SIGNALS ////////////////////////////////
  output wire [3:0] SrcReg1;        // Register ID of the first source register
  output wire [3:0] SrcReg2;        // Register ID of the second source register
  output wire [15:0] SrcReg1_data;  // Data from the first source register
  output wire [15:0] SrcReg2_data;  // Data from the second source register
  //////////////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////
  // Extracting instruction fields (opcode, registers, etc.) //
  /////////////////////////////////////////////////////////////
  // Get the opcode, Rd, Rs, Rt register IDs.
  assign opcode = pc_inst[15:12];
  assign reg_rd = pc_inst[11:8];
  assign reg_rs = pc_inst[7:4];
  assign reg_rt = pc_inst[3:0];

  // Get the immediate value for SLL/SRA/ROR/MEM/Branch instructions along with condition codes.
  assign ALU_imm = pc_inst[3:0];
  assign Mem_offset = pc_inst[3:0];
  assign LB_imm = pc_inst[7:0];
  assign Branch_imm = pc_inst[8:0];
  assign c_codes = pc_inst[11:9];

  // Select the source register for ALU operations.
  assign SrcReg1 = (RegSrc) ? reg_rd : reg_rs;
  assign SrcReg2 = (MemWrite) ? reg_rd : reg_rt;

  // Grab the LLB/LHB immediate or the ALU immediate based on the instruction.
  assign imm = (RegSrc) ? {8'h00, LB_imm} : {12'h000, ALU_imm};

  // Determine the 2nd ALU input, either zero-extended immediate or SrcReg2 data (Rd for save word or Rt otherwise).
  assign ALU_In2_step = (ALUSrc) ? imm : SrcReg2_data;

  // Sign extend the immediate memory offset.
  assign Mem_ex_offset = {{12{Mem_offset[3]}}, Mem_offset};

  // Get the second ALU input based on whether it is LW/SW instruction or not.
  assign ALU_In2 = (MemEnable) ? Mem_ex_offset : ALU_In2_step;
  /////////////////////////////////////////////////////////////

  /////////////////////////////////////////
  // Instantiate the Branch Control Unit //
  /////////////////////////////////////////
  Branch_control iBC (
      .C(c_codes),
      .I(Branch_imm),
      .F({ZF, VF, NF}),
      .Rs(SrcReg1_data),
      .Branch(Branch),
      .BR(pc_inst[12]),
      .PC_next(pc_next),
      .Branch_taken(Branch_taken),
      .PC_branch(Branch_target)
  );

  ///////////////////////////////////
  // Instantiate the Register File //
  ///////////////////////////////////
  RegisterFile iRF (
      .clk(clk),
      .rst(rst),
      .SrcReg1(SrcReg1),
      .SrcReg2(SrcReg2),
      .DstReg(reg_rd),
      .WriteReg(RegWrite),
      .DstData(RegWriteData),
      .SrcData1(SrcReg1_data),
      .SrcData2(SrcReg2_data)
  );

  //////////////////////////////////
  // Instantiate the Control Unit //
  //////////////////////////////////
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

endmodule

`default_nettype wire // Reset default behavior at the end