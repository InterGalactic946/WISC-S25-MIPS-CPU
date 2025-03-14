`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////////
// ID_EX_pipe_reg.v: Instruction Decode to Execute Pipeline //
//                                                           //
// This module represents the pipeline register between the  //
// Instruction Decode (ID) stage and the Execute (EX) stage. //
// It holds decoded instruction fields, control signals, and //
// register values while passing them to the EX stage.       //
///////////////////////////////////////////////////////////////
module ID_EX_pipe_reg (
    input wire clk,      // System clock
    input wire rst,      // Active high synchronous reset
    input wire flush,    // Flush pipeline register (clears signals)
    
    // Decoded instruction signals
    input wire [3:0] opcode_in,
    input wire [3:0] reg_rd_in,
    input wire [3:0] reg_rs_in,
    input wire [3:0] reg_rt_in,
    input wire [3:0] ALU_imm_in,
    input wire [3:0] Mem_offset_in,
    input wire [7:0] LB_imm_in,
    input wire [8:0] Branch_imm_in,
    input wire [2:0] c_codes_in,
    
    // Control unit signals
    input wire RegSrc_in,
    input wire RegWrite_in,
    input wire Branch_in,
    input wire ALUSrc_in,
    input wire [3:0] ALUOp_in,
    input wire Z_en_in, NV_en_in,
    input wire MemWrite_in,
    input wire MemEnable_in,
    input wire MemToReg_in,
    input wire HLT_in,
    input wire PCS_in,
    
    // Source register signals
    input wire [3:0] SrcReg1_in,
    input wire [3:0] SrcReg2_in,
    input wire [15:0] SrcReg1_data_in,
    input wire [15:0] SrcReg2_data_in,
    
    // Outputs to EX stage
    output wire [3:0] ID_EX_opcode,
    output wire [3:0] ID_EX_reg_rd,
    output wire [3:0] ID_EX_reg_rs,
    output wire [3:0] ID_EX_reg_rt,
    output wire [3:0] ID_EX_ALU_imm,
    output wire [3:0] ID_EX_Mem_offset,
    output wire [7:0] ID_EX_LB_imm,
    output wire [8:0] ID_EX_Branch_imm,
    output wire [2:0] ID_EX_c_codes,
    output wire ID_EX_RegSrc,
    output wire ID_EX_RegWrite,
    output wire ID_EX_Branch,
    output wire ID_EX_ALUSrc,
    output wire [3:0] ID_EX_ALUOp,
    output wire ID_EX_Z_en, ID_EX_NV_en,
    output wire ID_EX_MemWrite,
    output wire ID_EX_MemEnable,
    output wire ID_EX_MemToReg,
    output wire ID_EX_HLT,
    output wire ID_EX_PCS,
    output wire [3:0] ID_EX_SrcReg1,
    output wire [3:0] ID_EX_SrcReg2,
    output wire [15:0] ID_EX_SrcReg1_data,
    output wire [15:0] ID_EX_SrcReg2_data
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire wen;   // Register write enable signal.
  wire clr;   // Clear signal for pipeline registers
  //////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////
  // Implement the ID/EX Pipeline Register as structural/dataflow Verilog //
  /////////////////////////////////////////////////////////////////////////
  assign wen = ~stall;   // We write to the register whenever we don't stall.
  assign clr = flush | rst; // We clear registers whenever we flush or reset.

  // Pipeline registers for instruction signals
  dff iOpcode [3:0] (.q(ID_EX_opcode), .d(opcode_in), .wen({4{wen}}), .clk({4{clk}}), .rst({4{rst}}));
  dff iRegRd [3:0] (.q(ID_EX_reg_rd), .d(reg_rd_in), .wen({4{wen}}), .clk({4{clk}}), .rst({4{rst}}));
  dff iRegRs [3:0] (.q(ID_EX_reg_rs), .d(reg_rs_in), .wen({4{wen}}), .clk({4{clk}}), .rst({4{rst}}));
  dff iRegRt [3:0] (.q(ID_EX_reg_rt), .d(reg_rt_in), .wen({4{wen}}), .clk({4{clk}}), .rst({4{rst}}));
  dff iALUImm [3:0] (.q(ID_EX_ALU_imm), .d(ALU_imm_in), .wen({4{wen}}), .clk({4{clk}}), .rst({4{rst}}));
  dff iMemOffset [3:0] (.q(ID_EX_Mem_offset), .d(Mem_offset_in), .wen({4{wen}}), .clk({4{clk}}), .rst({4{rst}}));
  dff iLBImm [7:0] (.q(ID_EX_LB_imm), .d(LB_imm_in), .wen({8{wen}}), .clk({8{clk}}), .rst({8{rst}}));
  dff iBranchImm [8:0] (.q(ID_EX_Branch_imm), .d(Branch_imm_in), .wen({9{wen}}), .clk({9{clk}}), .rst({9{rst}}));
  dff iCCodes [2:0] (.q(ID_EX_c_codes), .d(c_codes_in), .wen({3{wen}}), .clk({3{clk}}), .rst({3{rst}}));

  // Pipeline registers for control and data signals
  dff iRegWrite (.q(ID_EX_RegWrite), .d(RegWrite_in), .wen(wen), .clk(clk), .rst(rst));
  dff iALUSrc (.q(ID_EX_ALUSrc), .d(ALUSrc_in), .wen(wen), .clk(clk), .rst(rst));
  dff iALUOp [3:0] (.q(ID_EX_ALUOp), .d(ALUOp_in), .wen({4{wen}}), .clk({4{clk}}), .rst({4{rst}}));
  dff iZEn (.q(ID_EX_Z_en), .d(Z_en_in), .wen(wen), .clk(clk), .rst(rst));
  dff iMemWrite (.q(ID_EX_MemWrite), .d(MemWrite_in), .wen(wen), .clk(clk), .rst(rst));
  dff iSrcReg1Data [15:0] (.q(ID_EX_SrcReg1_data), .d(SrcReg1_data_in), .wen({16{wen}}), .clk({16{clk}}), .rst({16{rst}}));
  dff iSrcReg2Data [15:0] (.q(ID_EX_SrcReg2_data), .d(SrcReg2_data_in), .wen({16{wen}}), .clk({16{clk}}), .rst({16{rst}}));

endmodule

`default_nettype wire // Reset default behavior at the end
