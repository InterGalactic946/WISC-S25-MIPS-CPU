`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////////
// ID_EX_pipe_reg.v: Instruction Decode to Execute Pipeline  //
//                                                           //
// This module represents the pipeline register between the  //
// Instruction Decode (ID) stage and the Execute (EX) stage. //
// It holds the Program Counter (PC) and control signals     //
// while passing them from the ID stage to the EX stage.     //
///////////////////////////////////////////////////////////////
module ID_EX_pipe_reg (
    input wire clk,                       // System clock
    input wire rst,                       // Active high synchronous reset
    input wire flush,                     // Flush pipeline register
    input wire [15:0] IF_ID_PC_next,      // Pipelined next PC from the fetch stage
    input wire [37:0] EX_signals,         // Execute stage control signals from the decode stage
    input wire [17:0] MEM_signals,        // Memory stage control signals from the decode stage
    input wire [7:0] WB_signals,          // Write-back stage control signals from the decode stage
    
    output wire [15:0] ID_EX_PC_next,     // Pipelined next PC passed to the execute stage
    output wire [37:0] ID_EX_EX_signals,  // Pipelined execute stage signals passed to the execute stage
    output wire [17:0] ID_EX_MEM_signals, // Pipelined memory stage signals passed to the execute stage
    output wire [7:0] ID_EX_WB_signals    // Pipelined write back stage signals passed to the execute stage
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire clr;                       // Clear signal for all registers
  ///////////////////////////// EXECUTE STAGE ////////////////////////////////////
  wire [15:0] ID_EX_ALU_In1;      // Pipelined First ALU input passed to the execute stage
  wire [15:0] ID_EX_ALU_In2;      // Pipelined Second ALU input passed to the execute stage
  wire [3:0] ID_EX_ALUOp;         // Pipelined ALU operation code passed to the execute stage
  wire ID_EX_Z_en, ID_EX_NV_en;   // Pipelined enable signals setting the Z, N, and V flags passed to the execute stage
  /////////////////////////// MEMORY STAGE ///////////////////////////////////////
  wire [15:0] ID_EX_MemWriteData; // Pipelined Memory write data signal passed to the execute stage
  wire ID_EX_MemEnable;           // Pipelined Memory enable signal passed to the execute stage
  wire ID_EX_MemWrite;            // Pipelined Memory write signal passed to the execute stage
  /////////////////////////// WRITE BACK STAGE ///////////////////////////////////
  wire [3:0] ID_EX_reg_rd;        // Pipelined Destination register address passed to the execute stage
  wire ID_EX_RegWrite;            // Pipelined Register write enable signal passed to the execute stage
  wire ID_EX_MemtoReg;            // Pipelined Memory to Register signal passed to the execute stage
  wire ID_EX_HLT;                 // Pipelined Halt signal passed to the execute stage
  wire ID_EX_PCS;                 // Pipelined PCS signal passed to the execute stage
  ////////////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////
  // Clear the pipeline register whenever we flush or during rst //
  /////////////////////////////////////////////////////////////////
  assign clr = flush | rst;

  ///////////////////////////////////////////////////////////////////////////////
  // Pipeline the next instruction's address to be passed to the execute stage //
  ///////////////////////////////////////////////////////////////////////////////
  CPU_Register iPC_NEXT_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(IF_ID_PC_next), .data_out(ID_EX_PC_next));
  ///////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////
  // Pipeline the EXECUTE control signals to be passed to the execute stage //
  ////////////////////////////////////////////////////////////////////////////
  // Register for storing First ALU input (EX_signals[37:22] == ALU_In1).
  CPU_Register iALU_IN1_REG (.clk(clk), .rst(clr), .wen(1'b1), .data_in(EX_signals[37:22]), .data_out(ID_EX_ALU_In1));

  // Register for storing Second ALU input (EX_signals[21:6] == ALU_In2).
  CPU_Register iALU_IN2_REG (.clk(clk), .rst(clr), .wen(1'b1), .data_in(EX_signals[21:6]), .data_out(ID_EX_ALU_In2));

  // Register for storing ALU operation code (EX_signals[5:2] == ALUOp).
  CPU_Register #(.WIDTH(4)) iALUOp_REG (.clk(clk), .rst(clr), .wen(1'b1), .data_in(EX_signals[5:2]), .data_out(ID_EX_ALUOp));

  // Register for storing flag register's Z enable signal (EX_signals[1] == Z_en).
  CPU_Register #(.WIDTH(1)) iZ_en_REG (.clk(clk), .rst(clr), .wen(1'b1), .data_in(EX_signals[1]), .data_out(ID_EX_Z_en));

  // Register for storing the flag register's NV enable signal (EX_signals[0] == NV_en).
  CPU_Register #(.WIDTH(1)) iNV_en_REG (.clk(clk), .rst(clr), .wen(1'b1), .data_in(EX_signals[0]), .data_out(ID_EX_NV_en));

  // Concatenate all pipelined execute stage signals.
  assign ID_EX_EX_signals = {ID_EX_ALU_In1, ID_EX_ALU_In2, ID_EX_ALUOp, ID_EX_Z_en, ID_EX_NV_en};
  /////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////
  // Pipeline the MEMORY control signals to be passed to the execute stage  //
  ////////////////////////////////////////////////////////////////////////////
  // Register for storing Memory write data (MEM_signals[17:2] == MemWriteData).
  CPU_Register #(.WIDTH(16)) iMemWriteData_REG (.clk(clk), .rst(clr), .wen(1'b1), .data_in(MEM_signals[17:2]), .data_out(ID_EX_MemWriteData));

  // Register for storing Memory enable signal (MEM_signals[1] == MemEnable).
  CPU_Register #(.WIDTH(1)) iMemEnable_REG (.clk(clk), .rst(clr), .wen(1'b1), .data_in(MEM_signals[1]), .data_out(ID_EX_MemEnable));

  // Register for storing Memory write signal (MEM_signals[0] == MemWrite).
  CPU_Register #(.WIDTH(1)) iMemWrite_REG (.clk(clk), .rst(clr), .wen(1'b1), .data_in(MEM_signals[0]), .data_out(ID_EX_MemWrite));

  // Concatenate all pipelined memory stage signals.
  assign ID_EX_MEM_signals = {ID_EX_MemWriteData, ID_EX_MemEnable, ID_EX_MemWrite};
  /////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////
  // Pipeline the WRITE-BACK control signals to be passed to the execute stage //
  ///////////////////////////////////////////////////////////////////////////////
  // Register for storing Destination register address (WB_signals[7:4] == reg_rd).
  CPU_Register #(.WIDTH(4)) iReg_rd_REG (.clk(clk), .rst(clr), .wen(1'b1), .data_in(WB_signals[7:4]), .data_out(ID_EX_reg_rd));

  // Register for storing Register write enable signal (WB_signals[3] == RegWrite).
  CPU_Register #(.WIDTH(1)) iRegWrite_REG (.clk(clk), .rst(clr), .wen(1'b1), .data_in(WB_signals[3]), .data_out(ID_EX_RegWrite));

  // Register for storing Memory to Register signal (WB_signals[2] == MemtoReg).
  CPU_Register #(.WIDTH(1)) iMemtoReg_REG (.clk(clk), .rst(clr), .wen(1'b1), .data_in(WB_signals[2]), .data_out(ID_EX_MemtoReg));

  // Register for storing Halt signal (WB_signals[1] == HLT).
  CPU_Register #(.WIDTH(1)) iHLT_REG (.clk(clk), .rst(clr), .wen(1'b1), .data_in(WB_signals[1]), .data_out(ID_EX_HLT));

  // Register for storing PCS signal (WB_signals[0] == PCS).
  CPU_Register #(.WIDTH(1)) iPCS_REG (.clk(clk), .rst(clr), .wen(1'b1), .data_in(WB_signals[0]), .data_out(ID_EX_PCS));

  // Concatenate all pipelined write back stage signals.
  assign ID_EX_WB_signals = {ID_EX_reg_rd, ID_EX_RegWrite, ID_EX_MemtoReg, ID_EX_HLT, ID_EX_PCS};
  /////////////////////////////////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end
