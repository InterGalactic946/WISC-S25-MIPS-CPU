`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////
// cpu.v                                  //
//                                       //
//////////////////////////////////////////
module cpu (
  input wire clk,        // System clock
  input wire rst_n,      // Active low reset
  output wire hlt,       // Asserted once the processor finishes an instruction before a HLT instruction
  output wire [15:0] pc  // PC value over the course of program execution
);

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  wire rst;

  wire [15:0] pc_addr;
  wire [15:0] nxt_pc;
  wire [15:0] pc_inst;

  // signals from instruction
  wire [3:0] opcode;
  wire [3:0] reg_rd;
  wire [3:0] reg_rs;
  wire [3:0] reg_rt;

  wire [3:0] ALU_imm;
  wire [3:0] Mem_offset;
  wire [7:0] LB_imm;
  wire [8:0] Brnch_imm;
  wire [2:0] c_codes;

  // signals to determine which registers are read
  wire [3:0] SrcReg1;
  wire [3:0] SrcReg2;
  
  // data from registers
  wire [15:0] SrcReg1_data;
  wire [15:0] SrcReg2_data;

  // Control signals
  wire RegSrc;
  wire RegWrite;
  wire Branch;
  wire ALUSrc;
  wire [3:0] ALUOp;
  wire Z_en, NV_en;
  wire Z_set, V_set, N_set;
  wire MemWrite;
  wire MemEnable;
  wire MemToReg;
  wire HLT;
  wire PCS;

  // ALU signals
  wire [15:0] imm; 
  wire [15:0] ALU_In2_step;
  wire [15:0] ALU_In2;
  wire [15:0] ALU_out;

  // Branch signals
  wire [15:0] Brnch_ex_imm;

  // Memory signals
  wire [15:0] Mem_ex_offset;
  wire [15:0] RegWriteData;
  wire [15:0] MemData;

  // flag signals
  wire ZF, VF, NF;

  /////////////////////////////////////////
  // Make reset active high for modules //
  ///////////////////////////////////////
  assign rst = ~rst_n;

  ////////////////////////////////
  // Fetch Instruction from PC //
  //////////////////////////////
  // Infer the instruction memory, it is always read enabled and never write enabled.
  memory1c iINSTR_MEM (.data_out(pc_inst),
               .data_in(16'h0000),
               .addr(pc_addr),
               .enable(1'b1),
               .wr(1'b0),
               .clk(clk),
               .rst(rst)
               );

  // Infer the PC Register.
  PC_Register(.clk(clk), .rst(rst), .nxt_pc(nxt_pc), .curr_pc(pc_addr));

  // Determines what the next pc address is based on branch taken/not.
  PC_control iPCC (.C(c_codes),
                   .I(Branch_imm),
                   .F({Z, V, N}),
                   .Rs(SrcReg1_data),
                   .Branch(Branch),
                   .BR(pc_inst[12]),
                   .PC_in(pc_addr),
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
  assign ALU_imm = pc_inst[3:0];
  assign Mem_offset = pc_inst[3:0];
  assign LB_imm = pc_inst[7:0];
  assign Brnch_imm = pc_inst[8:0];
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

  ///////////////////////////////////////////////////
  // Execute Instruction based on control signals //
  /////////////////////////////////////////////////
  // Grab the LLB/LHB immediate or the ALU immediate based on the instruction.
  assign imm = (RegSrc) ? {8'h00, LB_imm} : {12'h000, ALU_imm};

  // Determine the 2nd ALU input, either zero-extended immediate or SrcReg2 data (Rd for save word or Rt otherwise).
  assign ALU_In2_step = (ALUSrc) ? imm : SrcReg2_data;

  // Sign extend the immediate memory offset.
  SignExtender #(4) iMSE (.in(Mem_offset << 1'b1), .out(Mem_ex_offset));

  // Get the second ALU input based on whether it is LW/SW instruction or not.
  assign ALU_In2 = (MemEnable) ? Mem_ex_offset : ALU_In2_step;

  // Instantiate ALU.
  ALU iALU (.ALU_In1(SrcData1),
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
                    .Z_en(Z_en, .Z_set(Z_set),
                    .V_en(NV_en), .V_set(N_set),
                    .N_en(NV_en), .N_set(V_set),
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
  assign RegWriteData = (MemToReg) ? MemData : 
                                      (PCS) ? nxt_pc : ALU_out;

endmodule

`default_nettype wire  // Reset default behavior at the end
