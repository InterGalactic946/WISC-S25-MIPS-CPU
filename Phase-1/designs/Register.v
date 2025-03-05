`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////
// Register.v: 16-bit Register with Read/Write     //
//                                                 //
// This design implements a 16-bit register with   //
// separate read and write enables. It includes    //
// the ability to write data to the register when  //
// the `WriteReg` signal is asserted, and to read  //
// data using two separate read enables.           //
/////////////////////////////////////////////////////
module Register(clk, rst, D, WriteReg, ReadEnable1, ReadEnable2, Bitline1, Bitline2);

  input wire clk, rst;                  // system clock and active high synchronous reset inputs
  input wire [15:0] D;                  // 16-bit data input to the register
  input wire WriteReg;                  // used to enable writing to a register
  input wire ReadEnable1, ReadEnable2;  // enables reads from a register through two read paths
  inout wire [15:0] Bitline1, Bitline2; // read outputs of a register driven by tristate driver
  
  ///////////////////////////////////////////////
  // Implement Register as structural verilog //
  /////////////////////////////////////////////
  // Vector instantiate 16 BitCells comprising a register.
  BitCell iBIT_CELL [15:0] (.clk({16{clk}}), .rst({16{rst}}), .D(D), .WriteEnable({16{WriteReg}}), .ReadEnable1({16{ReadEnable1}}), .ReadEnable2({16{ReadEnable2}}), .Bitline1(Bitline1), .Bitline2(Bitline2));

endmodule

`default_nettype wire // Reset default behavior at the end