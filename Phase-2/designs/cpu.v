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

  /* FETCH stage signals */
  wire [15:0] PC_next;  // Next PC address
  wire [15:0] PC_inst;  // Instruction at the current PC address

  /* HAZARD DETECTION UNIT signals */
  wire wen; // Write enable signal for the PC

  /* DECODE stage signals */
  wire [3:0] opcode;         // opcode of the instruction
  wire [3:0] reg_rd;         // register ID of the destination register
  wire [3:0] reg_rs;         // register ID of the first source register
  wire [3:0] reg_rt;         // register ID of the second source register
  wire [3:0] ALU_imm;        // immediate for ALU instructions (SLL/SRA/ROR)
  wire [3:0] Mem_offset;     // offset for memory instructions (LW/SW)
  wire [7:0] LB_imm;         // immediate for LLB/LHB instructions
  wire [8:0] Branch_imm;     // immediate for branch instructions
  wire [2:0] c_codes;        // condition codes for branch instructions
  wire [15:0] Branch_target; // Computed branch target address
  wire Branch_taken;         // Signal used to determine whether branch is taken

  // Register IDs of source registers
  wire [3:0] SrcReg1; // Register ID of the first source register
  wire [3:0] SrcReg2; // Register ID of the second source register
  
  // Data from registers
  wire [15:0] SrcReg1_data; // Data from the first source register
  wire [15:0] SrcReg2_data; // Data from the second source register

  // Control signals
  wire RegSrc;               // Selects the register to read from based on LLB/LHB instructions and not
  wire RegWrite;             // Enables writing to the register file        
  wire Branch;               // Indicates a branch instruction
  wire ALUSrc;               // Selects the second ALU input based on the instruction type
  wire [3:0] ALUOp;          // ALU operation code
  wire Z_en, NV_en;          // Enables setting the Z, N, and V flags
  wire Z_set, V_set, N_set;  // Flags set by the ALU
  wire MemWrite;             // Enables writing to memory
  wire MemEnable;            // Enables reading from memory
  wire MemToReg;             // Selects the data to write back to the register file
  wire HLT;                  // Indicates a HLT instruction
  wire PCS;                  // Indicates a PCS instruction

  // ALU signals
  wire [15:0] imm;           // Sign extended immediate value for ALU operations
  wire [15:0] ALU_In2_step;  // Second ALU input based on the instruction type
  wire [15:0] ALU_In2;       // Second ALU input
  wire [15:0] ALU_out;       // ALU output

  // Memory signals
  wire [15:0] Mem_ex_offset;  // Sign extended memory offset
  wire [15:0] RegWriteData;   // Data to write back to the register file
  wire [15:0] MemData;        // Data read from memory

  // Flag signals
  wire ZF, VF, NF;
  //////////////////////////////////////////////////

  /////////////////////////////////////////
  // Make reset active high for modules //
  ///////////////////////////////////////
  assign rst = ~rst_n;

  ////////////////////////////////
  // Fetch Instruction from PC //
  //////////////////////////////
  Fetch iFETCH (
        .clk(clk),
        .rst(rst),
        .wen(wen),
        .Branch(Branch),
        .Branch_target(Branch_target),
        .Branch_taken(Branch_taken),
        .PC_next(PC_next),
        .PC_inst(PC_inst)
  );
  /////////////////////////////////////////////////////
  // Decode instruction and get data from registers //
  ///////////////////////////////////////////////////
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

  /* Determine which register we are reading. */
  // Read from Rd for LLB/LHB instructions and Rs for remaining instructions.
  assign SrcReg1 = (RegSrc) ? reg_rd : reg_rs;

  // Read from Rd for store instructions or Rt for any other instructions.
  assign SrcReg2 = (MemWrite) ? reg_rd : reg_rt;

  // Instantiate the register file for the CPU.
  RegisterFile iRF(.clk(clk),
                   .rst(rst),
                   .SrcReg1(SrcReg1),
                   .SrcReg2(SrcReg2),
                   .DstReg(reg_rd),
                   .WriteReg(RegWrite),
                   .DstData(RegWriteData),
                   .SrcData1(SrcReg1_data),
                   .SrcData2(SrcReg2_data)
                   );

  // Decodes the opcode and outputs the necessary control signals.
  ControlUnit iCC(.Opcode(opcode), 
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

  // Halts the processor if a HLT instruction is encountered.
  assign hlt = HLT;
  ///////////////////////////////////////////////////
  // Execute Instruction based on control signals //
  /////////////////////////////////////////////////
  // Grab the LLB/LHB immediate or the ALU immediate based on the instruction.
  assign imm = (RegSrc) ? {8'h00, LB_imm} : {12'h000, ALU_imm};

  // Determine the 2nd ALU input, either zero-extended immediate or SrcReg2 data (Rd for save word or Rt otherwise).
  assign ALU_In2_step = (ALUSrc) ? imm : SrcReg2_data;

  // Sign extend the immediate memory offset.
  assign Mem_ex_offset = {{12{Mem_offset[3]}}, Mem_offset};

  // Get the second ALU input based on whether it is LW/SW instruction or not.
  assign ALU_In2 = (MemEnable) ? Mem_ex_offset : ALU_In2_step;

  // Instantiate ALU.
  ALU iALU (.ALU_In1(SrcReg1_data),
            .ALU_In2(ALU_In2),
            .Opcode(ALUOp),
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
