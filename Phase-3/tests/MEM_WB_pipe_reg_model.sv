////////////////////////////////////////////////////////////////
// MEM_WB_pipe_reg_model.sv: Mem to WB Pipeline Register      //
//                                                            //
// This module represents a model MEM/WB pipeline register    //
// for the CPU.                                               //
////////////////////////////////////////////////////////////////
module MEM_WB_pipe_reg_model (
    input logic clk,                        // System clock
    input logic rst,                        // Active high synchronous reset
    input logic flush,                      // Flush pipeline register

    input logic [15:0] EX_MEM_PC_next,      // Pipelined next PC from the fetch stage
    input logic [15:0] EX_MEM_ALU_out,      // Pipelined ALU output from the execute stage
    input logic [15:0] MemData,             // Data read out from data memory from the memory stage
    input logic [7:0]  EX_MEM_WB_signals,   // Pipelined write back stage signals from the decode stage

    // New inputs from Memory stage
    input logic [15:0] first_tag_LRU,       // First tag seen by the LRU during the memory stage
    input logic        first_match,         // Whether a match was seen in the cache
    input logic        DCACHE_hit,          // DCACHE hit signal from the memory stage

    output logic [15:0] MEM_WB_PC_next,     // Pipelined next PC passed to the write-back stage
    output logic [15:0] MEM_WB_ALU_out,     // Pipelined ALU result passed to the write-back stage
    output logic [15:0] MEM_WB_MemData,     // Pipelined data read from memory passed to the write-back stage
    output logic [7:0]  MEM_WB_WB_signals,  // Pipelined write back stage signals passed to the write-back stage

    // New outputs to Writeback stage
    output logic [15:0] MEM_WB_first_tag_LRU,  // Pipelined first tag LRU value
    output logic        MEM_WB_first_match,    // Pipelined first match flag
    output logic        MEM_WB_DCACHE_hit      // Pipelined DCACHE hit flag
);

  ///////////////////////////////////////////////
  // Declare any internal signals as type logic//
  ///////////////////////////////////////////////
  logic clr; // Clear signal for instruction word register

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
      MEM_WB_WB_signals[7:4] <= 4'b0000;
      MEM_WB_WB_signals[3]   <= 1'b0;
      MEM_WB_WB_signals[2]   <= 1'b0;
      MEM_WB_WB_signals[1]   <= 1'b0;
      MEM_WB_WB_signals[0]   <= 1'b0;
    end else begin
      MEM_WB_WB_signals[7:4] <= EX_MEM_WB_signals[7:4];
      MEM_WB_WB_signals[3]   <= EX_MEM_WB_signals[3];
      MEM_WB_WB_signals[2]   <= EX_MEM_WB_signals[2];
      MEM_WB_WB_signals[1]   <= EX_MEM_WB_signals[1];
      MEM_WB_WB_signals[0]   <= EX_MEM_WB_signals[0];
    end
  end

  //////////////////////////////////////////////////////////
  // New pipelined signals from memory to writeback stage //
  //////////////////////////////////////////////////////////
  always @(posedge clk) begin
    if (rst) begin
      MEM_WB_first_tag_LRU <= 16'h0000;
      MEM_WB_first_match   <= 1'b0;
      MEM_WB_DCACHE_hit    <= 1'b0;
    end else begin
      MEM_WB_first_tag_LRU <= first_tag_LRU;
      MEM_WB_first_match   <= first_match;
      MEM_WB_DCACHE_hit    <= DCACHE_hit;
    end
  end

endmodule