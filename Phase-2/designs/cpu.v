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
  wire [31:0] IF_ID_signals; // Pipelined current intruction word and next instruction's address in that order

  /* DECODE stage signals */
  wire [15:0] Branch_target; // Computed branch target address
  wire Branch_taken;         // Signal used to determine whether branch is taken
  wire [5:0] EX_signals,     // Execute stage control signals
  wire [1:0] MEM_signals,    // Memory stage control signals
  wire [7:0] WB_signals,     // Write-back stage control signals
  wire [15:0] ALU_In1,       // First ALU input
  wire [15:0] ALU_In2        // Second ALU input

  /* ID/EX Pipeline Register signals */
  wire [15:0] ID_EX_signals; // Stores EX, MEM, WB control signals in that order

  /* EXECUTE stage signals */
  wire [15:0] ALU_out;       // ALU output
  wire ZF, VF, NF;           // Flag signals
  wire Z_set, V_set, N_set;  // Flags set by ALU

  /* MEMORY stage signals */
  wire [15:0] MemData;        // Data read from memory

  /* MEM/WB Pipeline Register signals */
  wire [3:0] MEM_WB_reg_rd; // Register ID of the destination register
  wire MEM_WB_RegWrite;     // Write enable to the register file
  wire MEM_WB_MemToReg;     // Selects the data to write back to the register file
  wire MEM_WB_HLT;          // Indicates that the HLT instruction, if fetched, entered the WB stage
  wire MEM_WB_PCS;          // Indicates that the PCS instruction, if fetched, entered the WB stage

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
      .Branch_target(Branch_target),
      .Branch_taken(Branch_taken),
      .ALU_In1(ALU_In1),
      .ALU_In2(ALU_In2)
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
  ALU iALU (.ALU_In1(ID_EX_ALU_In2),
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
                    .Z_en(ID_EX_Z_en), .Z_set(Z_set),
                    .V_en(ID_EX_NV_en), .V_set(V_set),
                    .N_en(ID_EX_NV_en), .N_set(N_set),
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
