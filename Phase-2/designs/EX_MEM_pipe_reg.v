`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////////
// EX_MEM_pipe_reg.v: Execute to Memory Pipeline             //
//                                                           //
// This module represents the pipeline register between the  //
// Execute (EX) stage and the Memory (MEM) stage. It holds   //
// the ALU output and control signals while passing them     //
// from the EX stage to the MEM stage.                       //
///////////////////////////////////////////////////////////////
module EX_MEM_pipe_reg (
    input wire clk,                        // System clock
    input wire rst,                        // Active high synchronous reset
    input wire [15:0] ID_EX_PC_next,       // Pipelined next PC from the fetch stage
    input wire [15:0] ALU_out,             // ALU output from the execute stage
    input wire [3:0] ID_EX_SrcReg2,        // Pipelined second source register ID pfrom the decode stage
    input wire ForwardMEM_EX,              // Forwarding signal for MEM stage to EX stage for SW instruction
    input wire [15:0] MEM_WB_RegWriteData, // Register write data from the write-back stage
    input wire [17:0] ID_EX_MEM_signals,   // Pipelined memory stage signals from the decode stage
    input wire [7:0] ID_EX_WB_signals,     // Pipelined write back stage signals from the decode stage
    
    output wire [15:0] EX_MEM_PC_next,     // Pipelined next PC passed to the memory stage
    output wire [15:0] EX_MEM_ALU_out,     // Pipelined ALU output passed to the memory stage
    output wire [3:0] EX_MEM_SrcReg2,      // Pipelined second source register ID passed to the memory stage
    output wire [17:0] EX_MEM_MEM_signals, // Pipelined memory stage signals passed to the memory stage
    output wire [7:0] EX_MEM_WB_signals    // Pipelined write back stage signals passed to the memory stage
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire [15:0] MemWriteData; // Memory write data signal passed to the memory stage
  /////////////////////////// MEMORY STAGE ///////////////////////////////////////
  wire [15:0] EX_MEM_MemWriteData; // Pipelined Memory write data signal passed to the memory stage
  wire EX_MEM_MemEnable;           // Pipelined Memory enable signal passed to the memory stage
  wire EX_MEM_MemWrite;            // Pipelined Memory write signal passed to the memory stage
  /////////////////////////// WRITE BACK STAGE ///////////////////////////////////
  wire [3:0] EX_MEM_reg_rd;        // Pipelined Destination register address passed to the memory stage
  wire EX_MEM_RegWrite;            // Pipelined Register write enable signal passed to the memory stage
  wire EX_MEM_MemtoReg;            // Pipelined Memory to Register signal passed to the memory stage
  wire EX_MEM_HLT;                 // Pipelined Halt signal passed to the memory stage
  wire EX_MEM_PCS;                 // Pipelined PCS signal passed to the memory stage
  ////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Pipeline the next instruction's address to be passed to the memory stage //
  //////////////////////////////////////////////////////////////////////////////
  CPU_Register iPC_NEXT_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(ID_EX_PC_next), .data_out(EX_MEM_PC_next));
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////
  // Pipeline the ALU output to be passed to the memory stage //
  //////////////////////////////////////////////////////////////
  CPU_Register iALU_OUT_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(ALU_out), .data_out(EX_MEM_ALU_out));
  //////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////
  // Pipeline the MEMORY control signals to be passed to the memory stage  //
  ///////////////////////////////////////////////////////////////////////////
  // Register for storing second source register ID.
  CPU_Register #(.WIDTH(4)) iSrcReg2_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(ID_EX_SrcReg2), .data_out(EX_MEM_SrcReg2));

  // Choose between the register write data and the decoded memory write data.
  assign MemWriteData = (ForwardMEM_EX) ? MEM_WB_RegWriteData : ID_EX_MEM_signals[17:2];

  // Register for storing Memory write data (ID_EX_MEM_signals[17:2] == MemWriteData).
  CPU_Register #(.WIDTH(16)) iMemWriteData_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(MemWriteData), .data_out(EX_MEM_MemWriteData));

  // Register for storing Memory enable signal (ID_EX_MEM_signals[1] == MemEnable).
  CPU_Register #(.WIDTH(1)) iMemEnable_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(ID_EX_MEM_signals[1]), .data_out(EX_MEM_MemEnable));

  // Register for storing Memory write signal (ID_EX_MEM_signals[0] == MemWrite).
  CPU_Register #(.WIDTH(1)) iMemWrite_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(ID_EX_MEM_signals[0]), .data_out(EX_MEM_MemWrite));

  // Concatenate all pipelined memory stage signals.
  assign EX_MEM_MEM_signals = {EX_MEM_MemWriteData, EX_MEM_MemEnable, EX_MEM_MemWrite};
  /////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Pipeline the WRITE-BACK control signals to be passed to the memory stage //
  //////////////////////////////////////////////////////////////////////////////
  // Register for storing Destination register address (ID_EX_WB_signals[7:4] == reg_rd).
  CPU_Register #(.WIDTH(4)) iReg_rd_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(ID_EX_WB_signals[7:4]), .data_out(EX_MEM_reg_rd));

  // Register for storing Register write enable signal (ID_EX_WB_signals[3] == RegWrite).
  CPU_Register #(.WIDTH(1)) iRegWrite_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(ID_EX_WB_signals[3]), .data_out(EX_MEM_RegWrite));

  // Register for storing Memory to Register signal (ID_EX_WB_signals[2] == MemtoReg).
  CPU_Register #(.WIDTH(1)) iMemtoReg_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(ID_EX_WB_signals[2]), .data_out(EX_MEM_MemtoReg));

  // Register for storing Halt signal (ID_EX_WB_signals[1] == HLT).
  CPU_Register #(.WIDTH(1)) iHLT_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(ID_EX_WB_signals[1]), .data_out(EX_MEM_HLT));

  // Register for storing PCS signal (ID_EX_WB_signals[0] == PCS).
  CPU_Register #(.WIDTH(1)) iPCS_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(ID_EX_WB_signals[0]), .data_out(EX_MEM_PCS));

  // Concatenate all pipelined write back stage signals.
  assign EX_MEM_WB_signals = {EX_MEM_reg_rd, EX_MEM_RegWrite, EX_MEM_MemtoReg, EX_MEM_HLT, EX_MEM_PCS};
  /////////////////////////////////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end
