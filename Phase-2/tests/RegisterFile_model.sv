/////////////////////////////////////////////////////////////
// RegisterFile_model.sv: 16-bit Register File Model         //
//                                                           //
// This design implements a 16-bit register file for         //
// the model CPU.                                            //
/////////////////////////////////////////////////////////////
module RegisterFile_model (clk, rst, SrcReg1, SrcReg2, DstReg, WriteReg, DstData, SrcData1, SrcData2);
  
  input logic clk, rst;                  // system clock and active high synchronous reset inputs
  input logic [3:0] SrcReg1;             // 4-bit register ID for the first source register
  input logic [3:0] SrcReg2;             // 4-bit register ID for the second source register
  input logic [3:0] DstReg;              // 4-bit register ID for the destination register
  input logic WriteReg;                  // enable writing to a register
  input logic [15:0] DstData;            // 16-bit data to be written to the destination register
  output logic [15:0] SrcData1, SrcData2; // read outputs of both source registers

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic [15:0] regfile [0:15];         // 16x16 register file
  logic [15:0] DstData_operand;        // Data to write to a register
  //////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////
  // Implement Register as behavioral verilog  //
  ///////////////////////////////////////////////
  // Hardcode register 0 to always hold 16'h0000
  assign DstData_operand = (DstReg === 4'h0) ? 16'h0000 : DstData;
  
  // Asynchronous Read Process.
  assign SrcData1 = (WriteReg && (DstReg === SrcReg1)) ? DstData_operand : regfile[SrcReg1];
  assign SrcData2 = (WriteReg && (DstReg === SrcReg2)) ? DstData_operand : regfile[SrcReg2];

  // Synchronous Write Process.
  always_ff @(posedge clk) begin
    if (rst) begin
      // Reset all registers to zero
      regfile <= '{default: 16'h0000};
    end else if (WriteReg) begin
      // Write operation (avoid writing to register 0)
      regfile[DstReg] <= DstData_operand;
    end
  end
endmodule