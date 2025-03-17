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
  wire predicted_taken; // Predicted taken signal from the branch history table

  /* IF/ID Pipeline Register signals */
  wire [3:0] IF_ID_PC_curr;   // Pipelined lower 4-bits of current instruction address from the fetch stage
  wire [15:0] IF_ID_PC_next;  // Pipelined next instruction address from the fetch stage
  wire [15:0] IF_ID_PC_inst;  // Pipelined instruction word from the fetch stage
  wire IF_ID_predicted_taken; // Pipelined branch prediction from the fetch stage

  /* DECODE stage signals */
  wire [15:0] branch_target; // Computed branch target address
  wire branch_taken;         // Signal used to determine whether the branch is actually taken
  wire misprediction;        // Indicates the branch was incorrectly predicted in the fetch stage
  wire Branch;               // Indicates it is a branch instruction
  wire BR;                   // Indicates it is a branch register instruction
  wire [62:0] EX_signals;    // Execute stage control signals
  wire [17:0] MEM_signals;   // Memory stage control signals
  wire [7:0] WB_signals;     // Write-back stage control signals

  /* HAZARD DETECTION UNIT signals */
  wire PC_stall;             // Stall signal for the PC register
  wire IF_ID_stall;          // Stall signal for the IF/ID pipeline register
  wire IF_flush, ID_flush;   // Flush signals for each pipeline register

  /* ID/EX Pipeline Register signals */
  wire [3:0] ID_EX_SrcReg1;        // Pipelined first source register ID from the decode stage
  wire [3:0] ID_EX_SrcReg2;        // Pipelined second source register ID from the decode stage
  wire [15:0] ID_EX_ALU_In1;       // Pipelined first ALU input from the decode stage
  wire [15:0] ID_EX_ALU_imm;       // Pipelined ALU immediate input from the decode stage
  wire [15:0] ID_EX_ALU_In2;       // Pipelined second ALU input from the decode stage
  wire [3:0] ID_EX_ALUOp;          // Pipelined ALU operation code from the decode stage
  wire ID_EX_ALUSrc;               // Pipelined ALU select signal to choose between register/immediate operand from the decode stage
  wire ID_EX_Z_en, ID_EX_NV_en;    // Pipelined enable signals setting the Z, N, and V flags from the decode stage
  wire [17:0] ID_EX_MEM_signals;   // Pipelined Memory stage control signals from the decode stage
  wire [7:0] ID_EX_WB_signals;     // Pipelined Write-back stage control signals from the decode stage
  wire [15:0] ID_EX_PC_next;       // Pipelined next instruction address from the fetch stage

  /* EXECUTE stage signals */
  wire [15:0] ALU_out;             // ALU output
  wire ZF, VF, NF;                 // Flag signals

  /* FORWARDING UNIT signals */
  wire [1:0] ForwardA;              // Forwarding signal for the first ALU input (ALU_In1)
  wire [1:0] ForwardB;              // Forwarding signal for the second ALU input (ALU_In2)
  wire ForwardMEM;                  // Forwarding signal for MEM stage to MEM stage

  /* EX/MEM Pipeline Register signals */
  wire [15:0] EX_MEM_ALU_out;      // Pipelined data memory address/arithemtic computation result computed from the execute stage
  wire [15:0] EX_MEM_MemWriteData; // Pipelined write data for SW from the decode stage
  wire EX_MEM_MemEnable;           // Pipelined data memory access enable signal from the decode stage
  wire EX_MEM_MemWrite;            // Pipelined data memory write enable signal from the decode stage
  wire [7:0] EX_MEM_WB_signals;    // Pipelined Write-back stage control signals from the decode stage
  wire [15:0] EX_MEM_PC_next;      // Pipelined next instruction address from the fetch stage

  /* MEMORY stage signals */
  wire [15:0] MemData;             // Data read from memory
  wire [15:0] MemWriteData;        // Data written to memory

  /* MEM/WB Pipeline Register signals */
  wire [15:0] MEM_WB_MemData; // Pipelined data read from memory from the memory stage
  wire [15:0] MEM_WB_ALU_out; // Pipelined arithemtic computation result computed from the execute stage
  wire [3:0] MEM_WB_reg_rd;   // Pipelined register ID of the destination register from the decode stage
  wire MEM_WB_RegWrite;       // Pipelined write enable to the register file from the decode stage
  wire MEM_WB_MemToReg;       // Pipelined select signal to write data read from memory or ALU result back to the register file
  wire MEM_WB_HLT;            // Pipelined HLT signal from the decode stage (indicates that the HLT instruction, if fetched, entered the WB stage) 
  wire MEM_WB_PCS;            // Pipelined PCS signal from the decode stage (indicates that the PCS instruction, if fetched, entered the WB stage)
  wire [15:0] MEM_WB_PC_next; // Pipelined next instruction address from the fetch stage

  /* WRITE_BACK stage signals */
  wire [15:0] RegWriteData;   // Data to write back to the register file
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

  ////////////////////////////////
  // FETCH instruction from PC  //
  ////////////////////////////////
  Fetch iFETCH (
      .clk(clk), 
      .rst(rst), 
      .stall(PC_stall), 
      .actual_target(branch_target), 
      .actual_taken(branch_taken), 
      .predicted_taken(predicted_taken),
      .IF_ID_PC_curr(IF_ID_PC_curr), 
      .branch_mispredicted(misprediction),
      .PC_next(PC_next), 
      .PC_inst(PC_inst), 
      .PC_curr(pc)
  );
  ///////////////////////////////////

  /////////////////////////////////////////////////
  // Pass the instruction word, current PC, prediction, and the next PC address to the IF/ID pipeline register.
  IF_ID_pipe_reg iIF_ID (
    .clk(clk),
    .rst(rst),
    .stall(IF_ID_stall),
    .flush(IF_flush),
    .PC_curr(pc),
    .PC_next(PC_next),
    .PC_inst(PC_inst),
    .IF_ID_predicted_taken(IF_ID_predicted_taken),
    .IF_ID_PC_curr(IF_ID_PC_curr), 
    .IF_ID_PC_next(IF_ID_PC_next),
    .IF_ID_PC_inst(IF_ID_PC_inst)
  );
  /////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////
  // DECODE instruction word, resolve branches, and access register file   //
  ///////////////////////////////////////////////////////////////////////////
  Decode iDECODE (
    .clk(clk),
    .rst(rst),
    .flags({ZF, VF, NF}), 
    .pc_inst(IF_ID_PC_inst),
    .pc_next(IF_ID_PC_next),
    .MEM_WB_reg_rd(MEM_WB_reg_rd),
    .MEM_WB_RegWrite(MEM_WB_RegWrite),
    .RegWriteData(RegWriteData),
    .EX_signals(EX_signals),
    .MEM_signals(MEM_signals),
    .WB_signals(WB_signals),
    .is_branch(Branch),
    .is_BR(BR),
    .Branch_target(branch_target),
    .branch_taken(branch_taken),
    .branch_mispredicted(misprediction)
  );
  ///////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////
  // Instantiate the Hazard Detection Unit  //
  ////////////////////////////////////////////
  // ID_EX_WB_signals[7:4] == ID_EX_reg_rd, ID_EX_WB_signals[3] == ID_EX_RegWrite.
  // EX_MEM_WB_signals[7:4] == EX_MEM_reg_rd, EX_MEM_WB_signals[3] == EX_MEM_RegWrite.
  // ID_EX_MEM_signals[1] == ID_EX_MemEnable, ID_EX_MEM_signals[0] == ID_EX_MemWrite.
  // MEM_signals[1] == MemEnable.
  // WB_signals[1] == HLT.
  // EX_signals[62:59] == SrcReg1, EX_signals[58:55] == SrcReg2. 
  HazardDetectionUnit iHDU (
      .ID_EX_reg_rd(ID_EX_WB_signals[7:4]),
      .EX_MEM_reg_rd(EX_MEM_WB_signals[7:4]),
      .SrcReg1(EX_signals[62:59]),
      .SrcReg2(EX_signals[58:55]),
      .ID_EX_RegWrite(ID_EX_WB_signals[3]),
      .EX_MEM_RegWrite(ID_EX_WB_signals[3]),
      .ID_EX_MemEnable(ID_EX_MEM_signals[1]),
      .ID_EX_MemWrite(ID_EX_MEM_signals[0]),
      .MemWrite(MEM_signals[1]),
      .Branch(Branch),
      .HLT(WB_signals[1]),
      .BR(BR),
      .ID_EX_Z_en(ID_EX_Z_en),
      .ID_EX_NV_en(ID_EX_NV_en),
      .branch_mispredicted(misprediction),
      .branch_taken(taken),
      .PC_stall(PC_stall),
      .IF_ID_stall(IF_ID_stall),
      .ID_flush(ID_flush),
      .IF_flush(IF_flush)
  );
  ///////////////////////////////////////////////

  /////////////////////////////////////////////////
  // Pass the next PC, instruction word's control signals and operands to the ID/EX pipeline register.
  ID_EX_pipe_reg iID_EX (
      .clk(clk),
      .rst(rst),
      .flush(ID_flush),
      .IF_ID_PC_next(IF_ID_PC_next),
      .EX_signals(EX_signals),
      .MEM_signals(MEM_signals),
      .WB_signals(WB_signals),
      .ID_EX_PC_next(ID_EX_PC_next),
      .ID_EX_EX_signals({ID_EX_SrcReg1, ID_EX_SrcReg2,
      ID_EX_ALU_In1, ID_EX_ALU_imm, ID_EX_ALU_In2, 
      ID_EX_ALUOp, ID_EX_ALUSrc, ID_EX_Z_en, ID_EX_NV_en}),
      .ID_EX_MEM_signals(ID_EX_MEM_signals),
      .ID_EX_WB_signals(ID_EX_WB_signals)
  );
  /////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////
  // EXECUTE instruction and set flags based on the opcode //
  ///////////////////////////////////////////////////////////
  Execute iEXECUTE (
      .clk(clk),
      .rst(rst),
      .EX_MEM_ALU_in(EX_MEM_ALU_out),
      .MEM_WB_ALU_in(RegWriteData),
      .ALU_In1_step(ID_EX_ALU_In1),
      .ForwardA(ForwardA),
      .ForwardB(ForwardB),
      .ALU_imm(ID_EX_ALU_imm),
      .ALU_In2_step(ID_EX_ALU_In2),
      .ALUOp(ID_EX_ALUOp),
      .ALUSrc(ID_EX_ALUSrc),
      .Z_en(ID_EX_Z_en),
      .NV_en(ID_EX_NV_en),
      .ZF(ZF),
      .NF(NF),
      .VF(VF),
      .ALU_out(ALU_out)
  );
  ////////////////////////////////////////////////////////////

  //////////////////////////////////////
  // Instantiate the Forwarding Unit  //
  //////////////////////////////////////
  // (EX_MEM_WB_signals[7:4] == EX_MEM_reg_rd), EX_MEM_WB_signals[3] == EX_MEM_RegWrite).
  ForwardingUnit iFWD (
    .ID_EX_SrcReg1(ID_EX_SrcReg1),
    .ID_EX_SrcReg2(ID_EX_SrcReg2),
    .EX_MEM_reg_rd(EX_MEM_WB_signals[7:4]),
    .MEM_WB_reg_rd(MEM_WB_reg_rd),
    .EX_MEM_RegWrite(EX_MEM_WB_signals[3]),
    .MEM_WB_RegWrite(MEM_WB_RegWrite),
    .ForwardA(ForwardA),
    .ForwardB(ForwardB),
    .ForwardMEM(ForwardMEM)
  );
  ///////////////////////////////////////

  /////////////////////////////////////////////////
  // Pass the next PC, ALU output along with control signals to the EX/MEM pipeline register. 
  EX_MEM_pipe_reg iEX_MEM (
      .clk(clk),
      .rst(rst),
      .ALU_out(ALU_out),
      .ID_EX_PC_next(ID_EX_PC_next),
      .ID_EX_MEM_signals(ID_EX_MEM_signals),
      .ID_EX_WB_signals(ID_EX_WB_signals),
      .EX_MEM_PC_next(EX_MEM_PC_next),
      .EX_MEM_ALU_out(EX_MEM_ALU_out),
      .EX_MEM_MEM_signals({EX_MEM_MemWriteData, EX_MEM_MemEnable, EX_MEM_MemWrite}),
      .EX_MEM_WB_signals(EX_MEM_WB_signals)
  );
  /////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////
  // Data MEMORY Access (read/write data for LW/SW as applicable) //
  //////////////////////////////////////////////////////////////////
  // Use the value read out from data memory from the previous instruction or previous ALU result if forwarded otherwise the current value. 
  assign MemWriteData = (ForwardMEM) ? RegWriteData : EX_MEM_MemWriteData;

  // Access data memory.
  memory1c iDATA_MEM (.data_out(MemData),
                      .data_in(MemWriteData),
                      .addr(EX_MEM_ALU_out),
                      .data(1'b1),
                      .enable(EX_MEM_MemEnable),
                      .wr(EX_MEM_MemWrite),
                      .clk(clk),
                      .rst(rst)
                    );
  //////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////
  // Pass the next PC, data read out from memory and ALU result to the MEM/WB pipeline register.
  MEM_WB_pipe_reg iMEM_WB (
      .clk(clk),
      .rst(rst),
      .EX_MEM_PC_next(EX_MEM_PC_next),
      .EX_MEM_ALU_out(EX_MEM_ALU_out),
      .MemData(MemData),
      .EX_MEM_WB_signals(EX_MEM_WB_signals),
      .MEM_WB_PC_next(MEM_WB_PC_next),
      .MEM_WB_ALU_out(MEM_WB_ALU_out),
      .MEM_WB_MemData(MEM_WB_MemData),
      .MEM_WB_WB_signals({MEM_WB_reg_rd, MEM_WB_RegWrite, MEM_WB_MemToReg, MEM_WB_HLT, MEM_WB_PCS})
  );
  /////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////
  // WRITE_BACK data to the register file based on PCS/LW/ALU as applicable //
  ////////////////////////////////////////////////////////////////////////////
  // Grab the data from memory for LW for write back or if it's PCS, we send (PC+2) for write back,
  // otherwise send the ALU output.
  assign RegWriteData = (MEM_WB_MemToReg) ? MEM_WB_MemData : ((MEM_WB_PCS) ? MEM_WB_PC_next : MEM_WB_ALU_out);

endmodule

`default_nettype wire  // Reset default behavior at the end