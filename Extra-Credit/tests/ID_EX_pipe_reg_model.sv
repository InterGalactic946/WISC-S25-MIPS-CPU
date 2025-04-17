///////////////////////////////////////////////////////////////
// ID_EX_pipe_reg_model.sv: Model ID_EX Pipeline Register    //
//                                                           //
// This module represents a model ID/EX pipeline register    //
// for the CPU.                                              //
///////////////////////////////////////////////////////////////
module ID_EX_pipe_reg_model (
    input logic clk,                       // System clock
    input logic rst,                       // Active high synchronous reset
    input logic flush,                     // Flush pipeline register
    input logic [15:0] IF_ID_PC_next,      // Pipelined next PC from the fetch stage
    input logic [62:0] EX_signals,         // Execute stage control signals from the decode stage
    input logic [17:0] MEM_signals,        // Memory stage control signals from the decode stage
    input logic [7:0] WB_signals,          // Write-back stage control signals from the decode stage
    
    output logic [15:0] ID_EX_PC_next,     // Pipelined next PC passed to the execute stage
    output logic [62:0] ID_EX_EX_signals,  // Pipelined execute stage signals passed to the execute stage
    output logic [17:0] ID_EX_MEM_signals, // Pipelined memory stage signals passed to the execute stage
    output logic [7:0] ID_EX_WB_signals    // Pipelined write back stage signals passed to the execute stage
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic clr; // Clear signal for all registers

  /////////////////////////////////////////////////////////////////
  // Clear the pipeline register whenever we flush or during rst //
  /////////////////////////////////////////////////////////////////
  assign clr = flush | rst;

  ///////////////////////////////////////////////////////////////////////////////
  // Pipeline the next instruction's address to be passed to the execute stage //
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge clk)
    if (rst)
      ID_EX_PC_next <= 16'h0000;
    else
      ID_EX_PC_next <= IF_ID_PC_next;
  ///////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////
  // Pipeline the EXECUTE control signals to be passed to the execute stage //
  ////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    if (clr) begin
      ID_EX_EX_signals[62:59] <= 4'h0;
      ID_EX_EX_signals[58:55] <= 4'h0;
      ID_EX_EX_signals[54:39] <= 16'h0000;
      ID_EX_EX_signals[38:23] <= 16'h0000;
      ID_EX_EX_signals[22:7] <= 16'h0000;
      ID_EX_EX_signals[6:3] <= 4'h0;
      ID_EX_EX_signals[2] <= 1'b0;
      ID_EX_EX_signals[1] <= 1'b0;
      ID_EX_EX_signals[0] <= 1'b0;
    end else begin
      ID_EX_EX_signals[62:59] <= EX_signals[62:59];
      ID_EX_EX_signals[58:55] <= EX_signals[58:55];
      ID_EX_EX_signals[54:39] <= EX_signals[54:39];
      ID_EX_EX_signals[38:23] <= EX_signals[38:23];
      ID_EX_EX_signals[22:7]  <= EX_signals[22:7];
      ID_EX_EX_signals[6:3] <= EX_signals[6:3];
      ID_EX_EX_signals[2] <= EX_signals[2];
      ID_EX_EX_signals[1] <= EX_signals[1];
      ID_EX_EX_signals[0] <= EX_signals[0];
    end
  end

  ////////////////////////////////////////////////////////////////////////////
  // Pipeline the MEMORY control signals to be passed to the execute stage  //
  ////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    if (clr) begin
      ID_EX_MEM_signals[17:2] <= 16'h0000;
      ID_EX_MEM_signals[1] <= 1'b0;
      ID_EX_MEM_signals[0] <= 1'b0;
    end else begin
      ID_EX_MEM_signals[17:2] <= MEM_signals[17:2];
      ID_EX_MEM_signals[1] <= MEM_signals[1];
      ID_EX_MEM_signals[0] <= MEM_signals[0];
    end
  end

  ///////////////////////////////////////////////////////////////////////////////
  // Pipeline the WRITE-BACK control signals to be passed to the execute stage //
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    if (clr) begin
      ID_EX_WB_signals[7:4] <= 16'h0000;
      ID_EX_WB_signals[3] <= 1'b0;
      ID_EX_WB_signals[2] <= 1'b0;
      ID_EX_WB_signals[1] <= 1'b0;
      ID_EX_WB_signals[0] <= 1'b0;
    end else begin
      ID_EX_WB_signals[7:4] <= WB_signals[7:4];
      ID_EX_WB_signals[3] <= WB_signals[3];
      ID_EX_WB_signals[2] <= WB_signals[2];
      ID_EX_WB_signals[1] <= WB_signals[1];
      ID_EX_WB_signals[0] <= WB_signals[0];
    end
  end
  /////////////////////////////////////////////////////////////////////////////

endmodule