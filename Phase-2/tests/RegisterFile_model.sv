/////////////////////////////////////////////////////////////
// RegisterFile_model.sv: 16-bit Register File Model       //
//                                                         //
// This design implements a 16-bit register file for       //
// the model CPU.                                          //
/////////////////////////////////////////////////////////////
module RegisterFile_model (clk, rst, SrcReg1, SrcReg2, DstReg, WriteReg, DstData, SrcData1, SrcData2);
  
  input logic clk, rst;                  // system clock and active high synchronous reset inputs
  input logic [3:0] SrcReg1;             // 4-bit register ID for the first source register
  input logic [3:0] SrcReg2;             // 4-bit register ID for the second source register
  input logic [3:0] DstReg;              // 4-bit register ID for the destination register
  input logic WriteReg;                  // used to enable writing to a register
  input logic [15:0] DstData;            // 16-bit data to be written to the destination register
  inout logic [15:0] SrcData1, SrcData2; // read outputs of both source registers

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic [15:0] regfile [0:15];         // Models a 16x16 regfile.
  logic [15:0] DstData_operand;        // Data to write to a register.
  logic [15:0] ReadData1, ReadData2;   // Data read out from both registers.
  //////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////
  // Implement Register as behaviorial verilog //
  ///////////////////////////////////////////////
  // Hardcode register 0 to always hold 0x0000, otherwise write whatever data that was meant to be.
  assign DstData_operand = (DstReg === 4'h0) ? 16'h0000 : DstData;
  
  // Synchronous Read Process.
  always_ff @(posedge clk) begin
    if (rst) begin
      // Reset all registers to zero
      regfile <= '{default: 16'h0000};
      ReadData1 <= 16'h0000;
      ReadData2 <= 16'h0000;
    end else begin
      // Read values on clock edge
      ReadData1 <= regfile[SrcReg1];
      ReadData2 <= regfile[SrcReg2];
    end
  end

  // Synchronous Write Process.
  always_ff @(posedge clk) begin
    if (!rst && WriteReg) begin
        // Write operation (avoid writing to register 0).
        regfile[DstReg] <= DstData_operand;
    end
  end

  // Reads in the latest data being written into the first register to allow for RF bypassing.
  assign SrcData1 = (WriteReg && (DstReg === SrcReg1)) ? DstData_operand : ReadData1;
  
  // Reads in the latest data being written into the second register to allow for RF bypassing.
  assign SrcData2 = (WriteReg && (DstReg === SrcReg2)) ? DstData_operand : ReadData2;

endmodule

`default_nettype wire // Reset default behavior at the end