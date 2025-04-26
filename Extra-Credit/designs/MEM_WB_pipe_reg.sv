////////////////////////////////////////////////////////////////
// MEM_WB_pipe_reg_model.sv: Mem to WB Pipeline Register      //
//                                                            //
// This module represents a model MEM/WB pipeline register    //
// for the CPU.                                               //
////////////////////////////////////////////////////////////////
module MEM_WB_pipe_reg (
    input logic clk,                        // System clock
    input logic rst,                        // Active high synchronous reset
    input logic flush,                      // Flush pipeline register

    input logic [15:0] EX_MEM_PC_next,      // Pipelined next PC from the fetch stage
    input logic [15:0] EX_MEM_ALU_out,      // Pipelined ALU output from the execute stage
    input logic [15:0] MemData,             // Data read out from data memory from the memory stage
    input logic [7:0]  EX_MEM_WB_signals,   // Pipelined write back stage signals from the decode stage

    output logic [15:0] MEM_WB_PC_next,     // Pipelined next PC passed to the write-back stage
    output logic [15:0] MEM_WB_ALU_out,     // Pipelined ALU result passed to the write-back stage
    output logic [15:0] MEM_WB_MemData,     // Pipelined data read from memory passed to the write-back stage
    output logic [7:0]  MEM_WB_WB_signals   // Pipelined write back stage signals passed to the write-back stage
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic clr;                  // Clear signal
  /////////////////////////// WRITE BACK STAGE ///////////////////////////////////
  logic [3:0] MEM_WB_reg_rd;  // Pipelined Destination register address passed to the write-back stage
  logic MEM_WB_RegWrite;      // Pipelined Register write enable signal passed to the write-back stage
  logic MEM_WB_MemtoReg;      // Pipelined Memory to Register signal passed to the write-back stage
  logic MEM_WB_HLT;           // Pipelined Halt signal passed to the write-back stage
  logic MEM_WB_PCS;           // Pipelined PCS signal passed to the write-back stage
  ////////////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////
  // Clear the pipeline register whenever we flush or during rst //
  /////////////////////////////////////////////////////////////////
  assign clr = flush | rst;

  //////////////////////////////////////////////////////////////////////////////////
  // Pipeline the next instruction's address to be passed to the write-back stage //
  //////////////////////////////////////////////////////////////////////////////////
  always @(posedge clk)
    if (rst)
      MEM_WB_PC_next <= 16'h0000;
    else
      MEM_WB_PC_next <= EX_MEM_PC_next;

  //////////////////////////////////////////////////////////////////
  // Pipeline the ALU output to be passed to the write-back stage //
  //////////////////////////////////////////////////////////////////
  always @(posedge clk)
    if (clr)
      MEM_WB_ALU_out <= 16'h0000;
    else
      MEM_WB_ALU_out <= EX_MEM_ALU_out;

  //////////////////////////////////////////////////////////////////////
  // Pipeline the MemData output to be passed to the write-back stage //
  //////////////////////////////////////////////////////////////////////
  always @(posedge clk)
    if (clr)
      MEM_WB_MemData <= 16'h0000;
    else
      MEM_WB_MemData <= MemData;

  //////////////////////////////////////////////////////////////////////////////////
  // Pipeline the WRITE-BACK control signals to be passed to the write-back stage //
  //////////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    if (clr) begin
      MEM_WB_reg_rd <= 4'h0;
      MEM_WB_RegWrite <= 1'b0;
      MEM_WB_MemtoReg <= 1'b0;
      MEM_WB_HLT <= 1'b0;
      MEM_WB_PCS <= 1'b0;
    end else begin
      MEM_WB_reg_rd <= EX_MEM_WB_signals[7:4];
      MEM_WB_RegWrite <= EX_MEM_WB_signals[3];
      MEM_WB_MemtoReg <= EX_MEM_WB_signals[2];
      MEM_WB_HLT <= EX_MEM_WB_signals[1];
      MEM_WB_PCS <= EX_MEM_WB_signals[0];
    end
  end

  // Concatenate all pipelined write back stage signals.
  assign MEM_WB_WB_signals = {MEM_WB_reg_rd, MEM_WB_RegWrite, MEM_WB_MemtoReg, MEM_WB_HLT, MEM_WB_PCS};

endmodule