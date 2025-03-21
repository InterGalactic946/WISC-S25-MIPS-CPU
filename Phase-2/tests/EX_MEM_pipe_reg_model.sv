///////////////////////////////////////////////////////////////
// EX_MEM_pipe_reg_model.sv: Model Ex to Mem Pipeline Reg    //
//                                                           //
// This module represents a model EX/MEM pipeline register   //
// for the CPU.                                              //
///////////////////////////////////////////////////////////////
module EX_MEM_pipe_reg_model (
    input logic clk,                        // System clock
    input logic rst,                        // Active high synchronous reset
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

  //////////////////////////////////////////////////////////////////////////////
  // Pipeline the next instruction's address to be passed to the memory stage //
  //////////////////////////////////////////////////////////////////////////////
  always @(posedge clk)
    if (rst)
      ID_EX_PC_next <= 16'h0000;
    else
      EX_MEM_PC_next <= ID_EX_PC_next;
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////
  // Pipeline the ALU output to be passed to the memory stage //
  //////////////////////////////////////////////////////////////
  always @(posedge clk)
    if (rst)
      ID_EX_PC_next <= 16'h0000;
    else
      EX_MEM_ALU_out <= ALU_out;
  //////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////
  // Pipeline the MEMORY control signals to be passed to the execute stage  //
  ////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    if (rst) begin
      EX_MEM_MEM_signals[17:2] <= 16'h0000;
      EX_MEM_MEM_signals[1]    <= 1'b0;
      EX_MEM_MEM_signals[0]    <= 1'b0;
    end else begin
      EX_MEM_MEM_signals[17:2] <= ID_EX_MEM_signals[17:2];
      EX_MEM_MEM_signals[1] <= ID_EX_MEM_signals[1];
      EX_MEM_MEM_signals[0] <= ID_EX_MEM_signals[0];
    end
  end

  ///////////////////////////////////////////////////////////////////////////////
  // Pipeline the WRITE-BACK control signals to be passed to the execute stage //
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    if (rst) begin
      EX_MEM_WB_signals[7:4] <= 16'h0000;
      EX_MEM_WB_signals[3] <= 1'b0;
      EX_MEM_WB_signals[2] <= 1'b0;
      EX_MEM_WB_signals[1] <= 1'b0;
      EX_MEM_WB_signals[0] <= 1'b0;
    end else begin
      EX_MEM_WB_signals[7:4] <= ID_EX_WB_signals[7:4];
      EX_MEM_WB_signals[3] <= ID_EX_WB_signals[3];
      EX_MEM_WB_signals[2] <= ID_EX_WB_signals[2];
      EX_MEM_WB_signals[1] <= ID_EX_WB_signals[1];
      EX_MEM_WB_signals[0] <= ID_EX_WB_signals[0];
    end
  end
  /////////////////////////////////////////////////////////////////////////////

endmodule