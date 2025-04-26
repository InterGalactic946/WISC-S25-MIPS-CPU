///////////////////////////////////////////////////////////////
// ID_EX_pipe_reg_model.sv: Model ID_EX Pipeline Register    //
//                                                           //
// This module represents a model ID/EX pipeline register    //
// for the CPU.                                              //
///////////////////////////////////////////////////////////////
module ID_EX_pipe_reg (
    input logic clk,                       // System clock
    input logic rst,                       // Active high synchronous reset
    input logic stall,                     // Stall signal (prevents updates)
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
  // Declare any internal signals as type logic  //
  /////////////////////////////////////////////////
  logic wen;                       // Register write enable signal.
  logic clr;                       // Clear signal for all registers
  ///////////////////////////// EXECUTE STAGE ////////////////////////////////////
  logic [3:0] ID_EX_SrcReg1;       // Pipelined first source register ID passed to the execute stage
  logic [3:0] ID_EX_SrcReg2;       // Pipelined second source register ID passed to the execute stage
  logic [15:0] ID_EX_ALU_In1;      // Pipelined first ALU input passed to the execute stage
  logic [15:0] ID_EX_ALU_imm;      // Pipelined ALU immediate input passed to the execute stage
  logic [15:0] ID_EX_ALU_In2;      // Pipelined second ALU input passed to the execute stage
  logic [3:0] ID_EX_ALUOp;         // Pipelined ALU operation code passed to the execute stage
  logic ID_EX_ALUSrc;              // Pipelined ALU select signal to choose between register/immediate operand passed to the execute stage
  logic ID_EX_Z_en, ID_EX_NV_en;   // Pipelined enable signals setting the Z, N, and V flags passed to the execute stage
  /////////////////////////// MEMORY STAGE ///////////////////////////////////////
  logic [15:0] ID_EX_MemWriteData; // Pipelined Memory write data signal passed to the execute stage
  logic ID_EX_MemEnable;           // Pipelined Memory enable signal passed to the execute stage
  logic ID_EX_MemWrite;            // Pipelined Memory write signal passed to the execute stage
  /////////////////////////// WRITE BACK STAGE ///////////////////////////////////
  logic [3:0] ID_EX_reg_rd;        // Pipelined Destination register address passed to the execute stage
  logic ID_EX_RegWrite;            // Pipelined Register write enable signal passed to the execute stage
  logic ID_EX_MemtoReg;            // Pipelined Memory to Register signal passed to the execute stage
  logic ID_EX_HLT;                 // Pipelined Halt signal passed to the execute stage
  logic ID_EX_PCS;                 // Pipelined PCS signal passed to the execute stage
  ////////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////
  // Model the ID/EX Pipeline Register //
  ///////////////////////////////////////
  // We write to the register whenever we don't stall.
  assign wen = ~stall;

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
    else if (wen)
      ID_EX_PC_next <= IF_ID_PC_next;
  ///////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////
  // Pipeline the EXECUTE control signals to be passed to the execute stage //
  ////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    if (clr) begin
      ID_EX_SrcReg1 <= 4'h0;
      ID_EX_SrcReg2 <= 4'h0;
      ID_EX_ALU_In1 <= 16'h0000;
      ID_EX_ALU_imm <= 16'h0000;
      ID_EX_ALU_In2 <= 16'h0000;
      ID_EX_ALUOp <= 4'h0;
      ID_EX_ALUSrc <= 1'b0;
      ID_EX_Z_en <= 1'b0;
      ID_EX_NV_en <= 1'b0;
    end else if (wen) begin
      ID_EX_SrcReg1 <= EX_signals[62:59];
      ID_EX_SrcReg2 <= EX_signals[58:55];
      ID_EX_ALU_In1 <= EX_signals[54:39];
      ID_EX_ALU_imm <= EX_signals[38:23];
      ID_EX_ALU_In2  <= EX_signals[22:7];
      ID_EX_ALUOp <= EX_signals[6:3];
      ID_EX_ALUSrc <= EX_signals[2];
      ID_EX_Z_en <= EX_signals[1];
      ID_EX_NV_en <= EX_signals[0];
    end
  end

  // Concatenate all pipelined execute stage signals.
  assign ID_EX_EX_signals = {ID_EX_SrcReg1, ID_EX_SrcReg2, ID_EX_ALU_In1, ID_EX_ALU_imm, ID_EX_ALU_In2, ID_EX_ALUOp, ID_EX_ALUSrc, ID_EX_Z_en, ID_EX_NV_en};
  /////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////
  // Pipeline the MEMORY control signals to be passed to the execute stage  //
  ////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    if (clr) begin
      ID_EX_MemWriteData <= 16'h0000;
      ID_EX_MemEnable <= 1'b0;
      ID_EX_MemWrite <= 1'b0;
    end else if (wen) begin
      ID_EX_MemWriteData <= MEM_signals[17:2];
      ID_EX_MemEnable <= MEM_signals[1];
      ID_EX_MemWrite <= MEM_signals[0];
    end
  end

  // Concatenate all pipelined memory stage signals.
  assign ID_EX_MEM_signals = {ID_EX_MemWriteData, ID_EX_MemEnable, ID_EX_MemWrite};
  /////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////
  // Pipeline the WRITE-BACK control signals to be passed to the execute stage //
  ///////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    if (clr) begin
      ID_EX_reg_rd <= 4'h0;
      ID_EX_RegWrite <= 1'b0;
      ID_EX_MemtoReg <= 1'b0;
      ID_EX_HLT <= 1'b0;
      ID_EX_PCS <= 1'b0;
    end else if (wen) begin
      ID_EX_reg_rd <= WB_signals[7:4];
      ID_EX_RegWrite <= WB_signals[3];
      ID_EX_MemtoReg <= WB_signals[2];
      ID_EX_HLT <= WB_signals[1];
      ID_EX_PCS <= WB_signals[0];
    end
  end

  // Concatenate all pipelined write back stage signals.
  assign ID_EX_WB_signals = {ID_EX_reg_rd, ID_EX_RegWrite, ID_EX_MemtoReg, ID_EX_HLT, ID_EX_PCS};
  /////////////////////////////////////////////////////////////////////////////

endmodule