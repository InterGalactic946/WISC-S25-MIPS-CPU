`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////
// cpu.v: Central Processing Unit Module                 //  
//                                                       //
// This module represents the CPU core, responsible for  //
// fetching, decoding, executing instructions, and       //
// managing memory and registers. It integrates the      //
// instruction memory, program counter, ALU, registers,  //
// and control unit to facilitate program execution.     //
///////////////////////////////////////////////////////////
module cpu (clk, rst_n, hlt, pc);

  input wire clk;         // System clock
  input wire rst_n;       // Active low synchronous reset
  output wire hlt;        // Asserted once the processor finishes an instruction before a HLT instruction
  output wire [15:0] pc;  // PC value over the course of program execution

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  wire rst; // Active high synchronous reset signal

  /* HAZARD DETECTION UNIT signals */
  wire PC_stall;                     // Stall signal for the PC register
  wire IF_ID_stall;                  // Stall signal for the IF/ID pipeline register
  wire IF_flush, ID_flush, EX_flush; // Flush signals for each pipeline register
  
  /* FETCH stage signals */
  wire [15:0] PC_next; // Next PC address
  wire [15:0] PC_inst; // Instruction at the current PC address

  /* IF/ID Pipeline Register signals */
  wire [15:0] IF_ID_PC_inst; // Pipelined instruction word from the fetch stage
  wire [15:0] IF_ID_PC_next; // Pipelined next instruction address from the fetch stage

  /* DECODE stage signals */
  /////////////////////////// DECODE INSTRUCTION SIGNALS ////////////////////////////
  wire [3:0] opcode;        // Opcode of the instruction
  wire [3:0] reg_rd;        // Register ID of the destination register
  wire [3:0] reg_rs;        // Register ID of the first source register
  wire [3:0] reg_rt;        // Register ID of the second source register
  wire [3:0] ALU_imm;       // Immediate for ALU instructions (SLL/SRA/ROR)
  wire [3:0] Mem_offset;    // Offset for memory instructions (LW/SW)
  wire [7:0] LB_imm;        // Immediate for LLB/LHB instructions
  wire [8:0] Branch_imm;    // Immediate for branch instructions
  wire [2:0] c_codes;       // Condition codes for branch instructions
  ///////////////////////////// CONTROL UNIT SIGNALS ///////////////////////////////
  wire RegSrc;              // Selects register source based on LLB/LHB instructions
  wire RegWrite;            // Enables writing to the register file        
  wire Branch;              // Indicates a branch instruction
  wire ALUSrc;              // Selects second ALU input based on instruction type
  wire [3:0] ALUOp;         // ALU operation code
  wire Z_en, NV_en;         // Enables setting the Z, N, and V flags
  wire MemWrite;            // Enables writing to memory
  wire MemEnable;           // Enables reading from memory
  wire MemToReg;            // Selects data to write back to the register file
  wire HLT;                 // Indicates a HLT instruction
  wire PCS;                 // Indicates a PCS instruction
  ////////////////////////// BRANCH CONTROL UNIT SIGNALS ///////////////////////////
  wire [15:0] Branch_target; // Computed branch target address
  wire Branch_taken;         // Signal used to determine whether branch is taken
  /////////////////////////// SOURCE REGISTER SIGNALS //////////////////////////////
  wire [3:0] SrcReg1;        // Register ID of the first source register
  wire [3:0] SrcReg2;        // Register ID of the second source register
  wire [15:0] SrcReg1_data;  // Data from the first source register
  wire [15:0] SrcReg2_data;  // Data from the second source register
  //////////////////////////////////////////////////////////////////////////////////

  /* ID/EX Pipeline Register signals */
  /////////////////////////// DECODE INSTRUCTION SIGNALS ////////////////////////////
  wire [3:0] ID_EX_ALU_imm;       // Pipelined immediate for ALU instructions (SLL/SRA/ROR)
  wire [3:0] ID_EX_Mem_offset;    // Pipelined offset for memory instructions (LW/SW)
  wire [7:0] ID_EX_LB_imm;        // Pipelined immediate for LLB/LHB instructions
  ///////////////////////////// CONTROL UNIT SIGNALS ///////////////////////////////
  wire ID_EX_RegWrite;            // Pipelined enable signal for writing to the register file
  wire ID_EX_ALUSrc;              // Pipelined selection of second ALU input based on instruction type
  wire [3:0] ID_EX_ALUOp;         // Pipelined ALU operation code
  wire ID_EX_Z_en, ID_EX_NV_en;   // Pipelined enable signals for setting the Z, N, and V flags
  wire ID_EX_MemWrite;            // Pipelined enable signal for writing to memory
  wire ID_EX_MemEnable;           // Pipelined enable signal for reading from memory
  wire ID_EX_MemToReg;            // Pipelined selection of data to write back to the register file
  wire ID_EX_HLT;                 // Pipelined halt instruction indicator
  wire ID_EX_PCS;                 // Pipelined PCS instruction indicator
  /////////////////////////// SOURCE REGISTER SIGNALS //////////////////////////////
  wire [3:0] ID_EX_SrcReg1;        // Pipelined register ID of the first source register
  wire [3:0] ID_EX_SrcReg2;        // Pipelined register ID of the second source register
  wire [15:0] ID_EX_SrcReg1_data;  // Pipelined data from the first source register
  wire [15:0] ID_EX_SrcReg2_data;  // Pipelined data from the second source register
  //////////////////////////////////////////////////////////////////////////////////

  /* EXECUTE stage signals */
  wire [15:0] imm;           // Sign extended immediate value for ALU operations
  wire [15:0] ALU_In2_step;  // Second ALU input based on the instruction type
  wire [15:0] ALU_In2;       // Second ALU input
  wire [15:0] ALU_out;       // ALU output
  wire ZF, VF, NF;           // Flag signals
  wire Z_set, V_set, N_set;  // Flags set by ALU

  // Memory signals
  wire [15:0] Mem_ex_offset;  // Sign extended memory offset
  wire [15:0] RegWriteData;   // Data to write back to the register file
  wire [15:0] MemData;        // Data read from memory

  /* MEM/WB Pipeline Register signals */
  wire MEM_WB_HLT;            // Indicates that the HLT instruction, if fetched, entered the WB stage.

  //////////////////////////////////////////////////

  /////////////////////////////////////////
  // Make reset active high for modules //
  ///////////////////////////////////////
  assign rst = ~rst_n;

  ///////////////////////////////////////////////////////////////////
  // Raise the hlt signal when the HLT instruction is encountered //
  //////////////////////////////////////////////////////////////////
  // Halts the processor if a HLT instruction is encountered and is in the WB stage.
  assign hlt = MEM_WB_HLT;

  ///////////////////////////////
  // FETCH instruction from PC //
  ///////////////////////////////
  Fetch iFETCH (
        .clk(clk),
        .rst(rst),
        .stall(PC_stall),
        .Branch_target(Branch_target),
        .Branch_taken(Branch_taken),
        .PC_next(PC_next),
        .PC_inst(PC_inst),
        .PC_curr(pc)
  );
  /////////////////////////////////////////////////

  /////////////////////////////////////////////////
  // Pass the instruction word and the next PC address to the IF/ID pipeline register.
  IF_ID_pipe_reg iIF_ID (
    .clk(clk),
    .rst(rst),
    .stall(IF_ID_stall),
    .flush(IF_flush),
    .PC_next_in(PC_next),
    .PC_inst_in(PC_inst),
    .PC_next_out(IF_ID_PC_next),
    .PC_inst_out(IF_ID_PC_inst)
  );
  /////////////////////////////////////////////////

  //////////////////////////////////////////////////
  // DECODE instruction word and resolve branches //
  //////////////////////////////////////////////////
  Decode iDECODE (
      .clk(clk),
      .rst(rst),
      .ZF(ZF),
      .VF(VF),
      .NF(NF),
      .pc_inst(IF_ID_PC_inst),
      .pc_next(IF_ID_PC_next),
      .RegSrc(RegSrc),
      .RegWrite(RegWrite),
      .Branch(Branch),
      .ALUSrc(ALUSrc),
      .ALUOp(ALUOp),
      .Z_en(Z_en),
      .NV_en(NV_en),
      .MemEnable(MemEnable),
      .MemWrite(MemWrite),
      .MemToReg(MemToReg),
      .HLT(HLT),
      .PCS(PCS),
      .Branch_target(Branch_target),
      .Branch_taken(Branch_taken),
      .SrcReg1(SrcReg1),
      .SrcReg2(SrcReg2),
      .SrcReg1_data(SrcReg1_data),
      .SrcReg2_data(SrcReg2_data),
      .opcode(opcode),
      .reg_rd(reg_rd),
      .reg_rs(reg_rs),
      .reg_rt(reg_rt),
      .ALU_imm(ALU_imm),
      .Mem_offset(Mem_offset),
      .LB_imm(LB_imm),
      .Branch_imm(Branch_imm),
      .c_codes(c_codes)
  );
  ////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////
  // Pass the instruction word's control signals and operands required to execute.
  ID_EX_pipe_reg iID_EX (
    .clk(clk),
    .rst(rst),
    .stall(IF_ID_stall),
    .flush(IF_flush),
    .PC_next_in(PC_next),
    .PC_inst_in(PC_inst),
    .PC_next_out(IF_ID_PC_next),
    .PC_inst_out(IF_ID_PC_inst)
  );
  /////////////////////////////////////////////////

  //////////////////////////////////////////////////
  // Execute Instruction based on control signals //
  //////////////////////////////////////////////////
  // Instantiate ALU.
  ALU iALU (.ALU_In1(ID_EX_SrcReg1_data),
            .ALU_In2(ID_EX_ALU_In2),
            .Opcode(ID_EX_ALUOp),
            .ALU_Out(ALU_out),
            .Z_set(Z_set),
            .N_set(N_set),
            .V_set(V_set)
            );

  // Instantiate the flag_register.
  flag_register iFR (.clk(clk),
                    .rst(rst),
                    .Z_en(Z_en), .Z_set(Z_set),
                    .V_en(NV_en), .V_set(V_set),
                    .N_en(NV_en), .N_set(N_set),
                    .Z(ZF),
                    .V(VF),
                    .N(NF)
                    );
  ///////////////////////////////////////////////////////////////////////
  // Read or Write to Memory and write back to Register if applicable //
  /////////////////////////////////////////////////////////////////////
  // Instantiate the data memory. 
  memory1c iDATA_MEM (.data_out(MemData),
                              .data_in(SrcReg2_data),
                              .addr(ALU_out),
                              .data(1'b1),
                              .enable(MemEnable),
                              .wr(MemWrite),
                              .clk(clk),
                              .rst(rst)
                              );
  ///////////////////////////////////////////////////////////
  // Determine what is being written back to the register //
  /////////////////////////////////////////////////////////
  // Grab the data from memory for LW for write back or if it's PCS, we send (PC+2) for write back,
  // otherwise send the ALU output.
  assign RegWriteData = (MemToReg) ? MemData : ((PCS) ? nxt_pc : ALU_out);

endmodule

`default_nettype wire  // Reset default behavior at the end
