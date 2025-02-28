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
  wire [2:0] Condition;

  // signals to determine which registers are read
  wire [3:0] SrcReg1;
  wire [3:0] SrcReg2;
  
  // data from registers
  wire [15:0] rs_data;
  wire [15:0] rt_data;

  // Control signals
  wire RegSrc;
  wire RegWrite;
  wire Branch;
  wire ALUSrc;
  wire [2:0] ALUOp;
  wire Z_en, V_en, N_en;
  wire MemWrite;
  wire MemEnable; // not sure if needed
  wire MemToReg;
  wire HLT;

  // ALU signals
  wire [15:0] ALU_in2;
  wire [15:0] ALU_out;

  // Branch signals
  wire [15:0] Brnch_ex_imm;

  // Memory signals
  wire [15:0] Mem_ex_offset;
  wire [15:0] RegWriteData;
  wire [15:0] MemData;

  // flag signals
  wire Z, V, N;

  /////////////////////////////////////////
  // Make reset active high for modules //
  ///////////////////////////////////////
  assign rst = ~rst_n;

  ////////////////////////////////
  // Fetch Instruction from PC //
  //////////////////////////////
  memory1c iPC(.data_out(pc_inst),
               .data_in(16'h0000),
               .addr(pc_addr),
               .enable(1'b1),
               .wr(1'b0),
               .clk(clk),
               .rst(rst)
               );

  // TODO: Create PC Register

  /////////////////////////////////////////////////////
  // Decode instruction and get data from registers //
  ///////////////////////////////////////////////////
  // assign instruction bits
  assign opcode = pc_inst[15:12];
  assign reg_rd = pc_inst[11:8];
  assign reg_rs = pc_inst[7:4];
  assign reg_rt = pc_inst[3:0];

  assign ALU_imm = pc_inst[3:0];
  assign Mem_offset = pc_inst[3:0];
  assign LB_imm = pc_inst[7:0];
  assign Brnch_imm = pc_inst[8:0];
  assign Condition = pc_inst[11:9];

  // determine which register we are reading
  assign SrcReg1 = (RegSrc) ? reg_rd : reg_rs;
  assign SrcReg2 = (MemWrite) ? reg_rd : reg_rt;

  // Read and Write data from registers
  RegisterFile iRF(.clk(clk),
                   .rst(rst),
                   .SrcReg1(reg_rs),
                   .SrcReg2(reg_rt),
                   .DstReg(reg_rd),
                   .WriteReg(RegWrite),
                   .DstData(RegWriteData),
                   .SrcData1(rs_data),
                   .SrcData2(rt_data)
                   );

  // TODO: CONTROL UNIT

  ///////////////////////////////////////////////////
  // Execute Instruction based on control signals //
  /////////////////////////////////////////////////
  // determine 2nd ALU input
  assign ALU_in2 = ALUSrc ? {12'h000, ALU_imm} : rt_data;

  // sign extend memory offset immediate
  SignExtender #(5) iMSE (.in(Mem_offset << 1), .out(Mem_ex_offset));

  // TODO: ALU UNIT
  // with ALU_out as rslt

  // TODO: finish flag_register
  flag_register iFR(.clk(clk),
                    .rst(rst),
                    .Z_en(Z_en), .Z_set(),
                    .V_en(V_en), .V_set(),
                    .N_en(N_en), .N_set(),
                    .Z(Z),
                    .V(V),
                    .N(N)
                    );

  // determines what the next pc address is
  PC_control iPCC (.C(Condition),
                   .I(Branch_imm),
                   .F({Z, V, N}),
                   .Rs(rs_data),
                   .Branch(Branch),
                   .BR(pc_inst[12]),
                   .PC_in(pc_addr),
                   .PC_out(nxt_pc)
                  );

  ///////////////////////////////////////////////////////////////////////
  // Read or Write to Memory and write back to Register if applicable //
  /////////////////////////////////////////////////////////////////////
  // TODO: Finish memory signals
  // Read or Write to Memory
  memory1c iMEM(.data_out(MemData),
                .data_in(rt_data),
                .addr(ALU_out),
                .enable(MemEnable),
                .wr(MemWrite),
                .clk(clk),
                .rst(rst)
                );

  ///////////////////////////////////////////////////////////
  // Determine what is being written back to the register //
  /////////////////////////////////////////////////////////
  assign RegWriteData = MemToReg ? MemData : ALU_out;


endmodule
