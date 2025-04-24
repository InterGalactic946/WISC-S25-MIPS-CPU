`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////////.///
// MEM_WB_pipe_reg.v: Memory to Write-Back Pipeline Register  //
//                                                            //
// This module represents the pipeline register between the   //
// Memory (MEM) stage and the Write-Back (WB) stage. It holds //
// the ALU output, memory data, and control signals while     //
// passing them from the MEM stage to the WB stage.           //
////////////////////////////////////////////////////////////////
module MEM_WB_pipe_reg (
    input wire clk,                        // System clock
    input wire rst,                        // Active high synchronous reset
    input wire [15:0] EX_MEM_PC_next,      // Pipelined next PC from the fetch stage
    input wire [15:0] EX_MEM_ALU_out,      // Pipelined ALU output from the execute stage
    input wire [15:0] MemData,             // Data read out from data memory from the memory stage
    input wire [7:0] EX_MEM_WB_signals,    // Pipelined write back stage signals from the decode stage
    
    output wire [15:0] MEM_WB_PC_next,     // Pipelined next PC passed to the write-back stage
    output wire [15:0] MEM_WB_ALU_out,     // Pipelined ALU result passed to the write-back stage
    output wire [15:0] MEM_WB_MemData,     // Pipelined data read from memory passed to the write-back stage
    output wire [7:0] MEM_WB_WB_signals    // Pipelined write back stage signals passed to the write-back stage
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  /////////////////////////// WRITE BACK STAGE ///////////////////////////////////
  wire [3:0] MEM_WB_reg_rd;  // Pipelined Destination register address passed to the write-back stage
  wire MEM_WB_RegWrite;      // Pipelined Register write enable signal passed to the write-back stage
  wire MEM_WB_MemtoReg;      // Pipelined Memory to Register signal passed to the write-back stage
  wire MEM_WB_HLT;           // Pipelined Halt signal passed to the write-back stage
  wire MEM_WB_PCS;           // Pipelined PCS signal passed to the write-back stage
  ////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////
  // Pipeline the next instruction's address to be passed to the write-back stage //
  //////////////////////////////////////////////////////////////////////////////////
  CPU_Register iPC_NEXT_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(EX_MEM_PC_next), .data_out(MEM_WB_PC_next));
  //////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////
  // Pipeline the ALU output to be passed to the write-back stage //
  //////////////////////////////////////////////////////////////////
  CPU_Register iALU_OUT_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(EX_MEM_ALU_out), .data_out(MEM_WB_ALU_out));
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////
  // Pipeline the MemData output to be passed to the write-back stage //
  //////////////////////////////////////////////////////////////////////
  CPU_Register iMEM_DATA_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(MemData), .data_out(MEM_WB_MemData));
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////
  // Pipeline the WRITE-BACK control signals to be passed to the write-back stage //
  //////////////////////////////////////////////////////////////////////////////////
  // Register for storing Destination register address (EX_MEM_WB_signals[7:4] == reg_rd).
  CPU_Register #(4) iReg_rd_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(EX_MEM_WB_signals[7:4]), .data_out(MEM_WB_reg_rd));

  // Register for storing Register write enable signal (EX_MEM_WB_signals[3] == RegWrite).
  CPU_Register #(1) iRegWrite_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(EX_MEM_WB_signals[3]), .data_out(MEM_WB_RegWrite));

  // Register for storing Memory to Register signal (EX_MEM_WB_signals[2] == MemtoReg).
  CPU_Register #(1) iMemtoReg_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(EX_MEM_WB_signals[2]), .data_out(MEM_WB_MemtoReg));

  // Register for storing Halt signal (EX_MEM_WB_signals[1] == HLT).
  CPU_Register #(1) iHLT_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(EX_MEM_WB_signals[1]), .data_out(MEM_WB_HLT));

  // Register for storing PCS signal (EX_MEM_WB_signals[0] == PCS).
  CPU_Register #(1) iPCS_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(EX_MEM_WB_signals[0]), .data_out(MEM_WB_PCS));

  // Concatenate all pipelined write back stage signals.
  assign MEM_WB_WB_signals = {MEM_WB_reg_rd, MEM_WB_RegWrite, MEM_WB_MemtoReg, MEM_WB_HLT, MEM_WB_PCS};
  //////////////////////////////////////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end
