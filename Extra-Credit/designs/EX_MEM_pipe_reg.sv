///////////////////////////////////////////////////////////////
// EX_MEM_pipe_reg_model.sv: Model Ex to Mem Pipeline Reg    //
//                                                           //
// This module represents a model EX/MEM pipeline register   //
// for the CPU.                                              //
///////////////////////////////////////////////////////////////
module EX_MEM_pipe_reg (
    input logic clk,                        // System clock
    input logic rst,                        // Active high synchronous reset
    input logic stall,                      // Stall signal (prevents updates)
    input logic [15:0] ID_EX_PC_next,       // Pipelined next PC from the fetch stage
    input logic [15:0] ALU_out,             // ALU output from the execute stage
    input logic [3:0] ID_EX_SrcReg2,        // Pipelined second source register ID pfrom the decode stage
    input logic [17:0] ID_EX_MEM_signals,   // Pipelined memory stage signals from the decode stage
    input logic [7:0] ID_EX_WB_signals,     // Pipelined write back stage signals from the decode stage
    
    output logic [15:0] EX_MEM_PC_next,     // Pipelined next PC passed to the memory stage
    output logic [15:0] EX_MEM_ALU_out,     // Pipelined ALU output passed to the memory stage
    output logic [3:0] EX_MEM_SrcReg2,      // Pipelined second source register ID passed to the memory stage
    output logic [17:0] EX_MEM_MEM_signals, // Pipelined memory stage signals passed to the memory stage
    output logic [7:0] EX_MEM_WB_signals    // Pipelined write back stage signals passed to the memory stage
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic wen;                        // Register write enable signal.
  /////////////////////////// MEMORY STAGE ///////////////////////////////////////
  logic [15:0] EX_MEM_MemWriteData; // Pipelined Memory write data signal passed to the memory stage
  logic EX_MEM_MemEnable;           // Pipelined Memory enable signal passed to the memory stage
  logic EX_MEM_MemWrite;            // Pipelined Memory write signal passed to the memory stage
  /////////////////////////// WRITE BACK STAGE ///////////////////////////////////
  logic [3:0] EX_MEM_reg_rd;        // Pipelined Destination register address passed to the memory stage
  logic EX_MEM_RegWrite;            // Pipelined Register write enable signal passed to the memory stage
  logic EX_MEM_MemtoReg;            // Pipelined Memory to Register signal passed to the memory stage
  logic EX_MEM_HLT;                 // Pipelined Halt signal passed to the memory stage
  logic EX_MEM_PCS;                 // Pipelined PCS signal passed to the memory stage
  ////////////////////////////////////////////////////////////////////////////////


  ///////////////////////////////////////
  // Model the EX/MEM Pipeline Register //
  ///////////////////////////////////////
  // We write to the register whenever we don't stall.
  assign wen = ~stall;

  //////////////////////////////////////////////////////////////////////////////
  // Pipeline the next instruction's address to be passed to the memory stage //
  //////////////////////////////////////////////////////////////////////////////
  always @(posedge clk)
    if (rst)
      EX_MEM_PC_next <= 16'h0000;
    else if (wen)
      EX_MEM_PC_next <= ID_EX_PC_next;
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////
  // Pipeline the ALU output to be passed to the memory stage //
  //////////////////////////////////////////////////////////////
  always @(posedge clk)
    if (rst)
      EX_MEM_ALU_out <= 16'h0000;
    else if (wen)
      EX_MEM_ALU_out <= ALU_out;
  //////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////
  // Pipeline the SrcReg2 input to be passed to the memory stage //
  /////////////////////////////////////////////////////////////////
  always @(posedge clk)
    if (rst)
      EX_MEM_SrcReg2 <= 4'h0;
    else if (wen)
      EX_MEM_SrcReg2 <= ID_EX_SrcReg2;
  //////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////
  // Pipeline the MEMORY control signals to be passed to the execute stage  //
  ////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    if (rst) begin
      EX_MEM_MemWriteData <= 16'h0000;
      EX_MEM_MemEnable    <= 1'b0;
      EX_MEM_MemWrite    <= 1'b0;
    end else if (wen) begin
      EX_MEM_MemWriteData <= ID_EX_MEM_signals[17:2];
      EX_MEM_MemEnable <= ID_EX_MEM_signals[1];
      EX_MEM_MemWrite <= ID_EX_MEM_signals[0];
    end
  end

  // Concatenate all pipelined memory stage signals.
  assign EX_MEM_MEM_signals = {EX_MEM_MemWriteData, EX_MEM_MemEnable, EX_MEM_MemWrite};
  /////////////////////////////////////////////////////////////////////////////


  ///////////////////////////////////////////////////////////////////////////////
  // Pipeline the WRITE-BACK control signals to be passed to the execute stage //
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    if (rst) begin
      EX_MEM_reg_rd <= 4'h0;
      EX_MEM_RegWrite <= 1'b0;
      EX_MEM_MemtoReg <= 1'b0;
      EX_MEM_HLT <= 1'b0;
      EX_MEM_PCS <= 1'b0;
    end else if (wen) begin
      EX_MEM_reg_rd <= ID_EX_WB_signals[7:4];
      EX_MEM_RegWrite <= ID_EX_WB_signals[3];
      EX_MEM_MemtoReg <= ID_EX_WB_signals[2];
      EX_MEM_HLT <= ID_EX_WB_signals[1];
      EX_MEM_PCS <= ID_EX_WB_signals[0];
    end
  end

  // Concatenate all pipelined write back stage signals.
  assign EX_MEM_WB_signals = {EX_MEM_reg_rd, EX_MEM_RegWrite, EX_MEM_MemtoReg, EX_MEM_HLT, EX_MEM_PCS};
  /////////////////////////////////////////////////////////////////////////////

endmodule