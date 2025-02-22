`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////////////
// RegisterFile.v: 16-bit Register File                    //
//                                                         //
// This design implements a 16-bit register file with      //
// multiple registers, each holding 16 bits of data. It    //
// allows reading from two source registers (`SrcReg1`     //
// and `SrcReg2`) and writing to a destination register    //
// (`DstReg`). The `WriteReg` signal enables writing       //
// data to the `DstReg`, and `DstData` is the data to be   //
// written.                                                //
/////////////////////////////////////////////////////////////
module RegisterFile(clk, rst, SrcReg1, SrcReg2, DstReg, WriteReg, DstData, SrcData1, SrcData2);
  
  input wire clk, rst;                  // system clock and active high synchronous reset inputs
  input wire [3:0] SrcReg1;             // 4-bit register ID for the first source register
  input wire [3:0] SrcReg2;             // 4-bit register ID for the second source register
  input wire [3:0] DstReg;              // 4-bit register ID for the destination register
  input wire WriteReg;                  // used to enable writing to a register
  input wire [15:0] DstData;            // 16-bit data to be written to the destination register
  inout wire [15:0] SrcData1, SrcData2; // read outputs of both source registers

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire [15:0] Wordline_1, Wordline_2; // Select lines for register 1 and 2.
  wire [15:0] Wordline_dst;           // Select line for destination register.
  wire [15:0] DstData_operand;        // Data to write to a register.
  wire [15:0] ReadData1, ReadData2;   // Data read out from both registers.
  //////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////
  // Implement Register as structural/dataflow verilog //
  //////////////////////////////////////////////////////
  // Instantiate two read register decoders.
  ReadDecoder_4_16 iREAD_1 (.RegId(SrcReg1), .Wordline(Wordline_1));
  ReadDecoder_4_16 iREAD_2 (.RegId(SrcReg2), .Wordline(Wordline_2));

  // Instantiate a single write decoder.
  WriteDecoder_4_16 iWRITE (.RegId(DstReg), .WriteReg(WriteReg), .Wordline(Wordline_dst));

  // Vector instantiate 16 registers comprising a register file.
  Register iREGISTER [15:0] (.clk({16{clk}}), .rst({16{rst}}), .D(DstData_operand), .WriteReg(Wordline_dst), .ReadEnable1(Wordline_1), .ReadEnable2(Wordline_2), .Bitline1(ReadData1), .Bitline2(ReadData2));

  // Hardcode register 0 to always hold 0x0000, otherwise write whatever data that was meant to be.
  assign DstData_operand = (DstReg == 4'h0) ? 16'h0000 : DstData;

endmodule

`default_nettype wire // Reset default behavior at the end