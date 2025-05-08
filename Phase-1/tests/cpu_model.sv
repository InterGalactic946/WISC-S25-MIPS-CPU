///////////////////////////////////////////////////////////
// cpu_model.sv: Model Central Processing Unit Module    //  
//                                                       //
// This module represents the CPU core, responsible for  //
// fetching, decoding, executing instructions, and       //
// managing memory and registers. It integrates the      //
// instruction memory, program counter, ALU, registers,  //
// and control unit to facilitate program execution.     //
///////////////////////////////////////////////////////////
module cpu_model (clk, rst_n, hlt, pc);

  input logic clk;         // System clock
  input logic rst_n;       // Active low synchronous reset
  output logic hlt;        // Asserted once the processor finishes an instruction before a HLT instruction
  output logic [15:0] pc;  // PC value over the course of program execution

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  logic rst; // Active high synchronous reset signal

  // Signals for the PC and instruction memory
  logic [15:0] nxt_pc;             // Next PC address
  logic [15:0] pc_inst;            // Instruction at the current PC address
  logic [15:0] inst_mem [0:65535]; // Instruction memory (read-only)

  // Signals from the decoded instruction
  logic [3:0] opcode;     // opcode of the instruction
  logic [3:0] reg_rd;     // register ID of the destination register
  logic [3:0] reg_rs;     // register ID of the first source register
  logic [3:0] reg_rt;     // register ID of the second source register
  logic [3:0] imm;        // immediate value decoded from the instruction
  logic [15:0] imm_ext;   // Sign-extended or zero-extended immediate from the instruction
  logic [7:0] LB_imm;     // immediate for LLB/LHB instructions
  logic [8:0] Branch_imm; // immediate for branch instructions
  logic [2:0] c_codes;    // condition codes for branch instructions
  logic [15:0] Mem_ex_offset;  // Sign extended memory offset

  // Register IDs of source registers
  logic [3:0] SrcReg1; // Register ID of the first source register
  logic [3:0] SrcReg2; // Register ID of the second source register
  
  // Data from registers
  logic [15:0] SrcReg1_data; // Data from the first source register
  logic [15:0] SrcReg2_data; // Data from the second source register

  // Control signals
  logic RegSrc;               // Selects the register to read from based on LLB/LHB instructions and not
  logic RegWrite;             // Enables writing to the register file        
  logic Branch;               // Indicates a branch instruction
  logic ALUSrc;               // Selects the second ALU input based on the instruction type
  logic [3:0] ALUOp;          // ALU operation code
  logic Z_en, NV_en;          // Enables setting the Z, N, and V flags
  logic Z_set, V_set, N_set;  // Flags set by the ALU
  logic MemWrite;             // Enables writing to memory
  logic MemEnable;            // Enables reading from memory
  logic MemToReg;             // Selects the data to write back to the register file
  logic HLT;                  // Indicates a HLT instruction
  logic PCS;                  // Indicates a PCS instruction

  // Execute signals
  logic [15:0] ALU_imm;       // Immediate for I-type ALU instructions
  logic [15:0] ALU_In1;       // First ALU input 
  logic [15:0] ALU_In2;       // Second ALU input based on the instruction type
  logic [15:0] ALU_out;       // ALU output
  logic ZF, VF, NF;           // Flags from the ALU indicating zero, overflow, and negative results

  // Memory signals
  logic [15:0] MemData;        // Data read from memory

  // Write back signals
  logic [15:0] RegWriteData;   // Data to be written back to the register file
  ////////////////////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////
  // Make reset active high for modules //
  ///////////////////////////////////////
  assign rst = ~rst_n;

  //////////////////////////////////////////////////////////////////
  // Raise the hlt signal when the HLT instruction is encountered //
  //////////////////////////////////////////////////////////////////
  assign hlt = HLT;

  ////////////////////////////////
  // Fetch Instruction from PC //
  //////////////////////////////
  // Model the instruction memory (read only).
  always_ff @(posedge clk) begin
    if (rst) begin
      // Initialize the instruction memory on reset.
      $readmemh("./tests/loadfile_all.img", inst_mem);
    end
  end

  // Asynchronously read out the instruction.
  assign pc_inst = inst_mem[pc[15:1]];

  // Infer the PC Register.
  always_ff @(posedge clk)
      if (rst)
        pc <= 16'h0000;
      else
        pc <= nxt_pc;

  // Determines what the next pc address is based on branch taken/not.
  PC_control_model iPCC (.C(c_codes),
                   .I(Branch_imm),
                   .F({ZF, VF, NF}),
                   .Rs(SrcReg1_data),
                   .Branch(Branch),
                   .BR(pc_inst[12]),
                   .PC_in(pc),
                   .PC_out(nxt_pc)
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
  assign imm = pc_inst[3:0];
  assign LB_imm = pc_inst[7:0];
  assign Branch_imm = pc_inst[8:0];
  assign c_codes = pc_inst[11:9];

  /* Determine which register we are reading. */
  // Read from Rd for LLB/LHB instructions and Rs for remaining instructions.
  assign SrcReg1 = (RegSrc) ? reg_rd : reg_rs;

  // Read from Rd for store instructions or Rt for any other instructions.
  assign SrcReg2 = (MemWrite) ? reg_rd : reg_rt;

  // Instantiate the register file for the CPU.
  RegisterFile_model iRF(.clk(clk),
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
  ControlUnit_model iCC(
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

  ///////////////////////////////////////////////////
  // Execute Instruction based on control signals //
  /////////////////////////////////////////////////
  // Sign-extend or zero-extend the immediate from the instruction based on memory vs non-memory instructions.
  assign imm_ext = (MemEnable) ? {{12{imm[3]}}, imm} : {12'h000, imm};

  // Grab the LLB/LHB immediate or the extended immediate based on the instruction as the ALU immediate.
  assign ALU_imm = (RegSrc) ? {8'h00, LB_imm} : imm_ext;
  
  // Get the first ALU input as the first register read out.
  assign ALU_In1 = SrcReg1_data;

  // Determine the 2nd ALU input, either immediate or SrcReg2 data (Rd for save word or Rt otherwise).
  assign ALU_In2 = (ALUSrc) ? ALU_imm : SrcReg2_data;

  // Instantiate ALU.
  ALU_model iALU_model (.ALU_In1(ALU_In1),
            .ALU_In2(ALU_In2),
            .Opcode(ALUOp),
            .ALU_Out(ALU_out),
            .Z_set(Z_set),
            .N_set(N_set),
            .V_set(V_set)
            );

  // Instantiate the model flag_register.
  flag_register_model iFR (.clk(clk),
                    .rst(rst),
                    .Z_en(Z_en), .Z_set(Z_set),
                    .V_en(NV_en), .V_set(V_set),
                    .N_en(NV_en), .N_set(N_set),
                    .ZF(ZF),
                    .VF(VF),
                    .NF(NF)
                    );

  /////////////////////////////
  // Read or Write to Memory //
  /////////////////////////////
  // Instantiate the data memory.
  memory iDATA_MEM (.data_out(MemData),
                      .data_in(SrcReg2_data),
                      .addr(ALU_out),
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