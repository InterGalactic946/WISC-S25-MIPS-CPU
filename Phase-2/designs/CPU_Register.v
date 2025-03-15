`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////
// CPU_Register.v: Parameterized Register Module  //
//                                                 //
// This design implements a parameterized register //
// with a configurable bit width. It supports      //
// synchronous write operations when the `wen`     //
// signal is asserted and allows reading the       //
// stored value. The register is implemented       //
// using vector instantiation of D flip-flops.     //
/////////////////////////////////////////////////////
module CPU_Register(clk, rst, wen, data_in, data_out);

  parameter WIDTH = 16;            // Width of each register in bits

  input wire clk, rst;             // system clock and active high synchronous reset inputs
  input wire wen;                  // used to enable writing to the register
  input wire [WIDTH-1:0] data_in;  // WIDTH-bit data input to the register
  inout wire [WIDTH-1:0] data_out; // read output of the register
  
  //////////////////////////////////////////////////
  // Implement CPU_Register as structural verilog //
  //////////////////////////////////////////////////
  // Vector instantiate WIDTH flops comprising a register.
  dff iREG [WIDTH-1:0] (.q(data_out), .d(data_in), .wen({WIDTH{wen}}), .clk({WIDTH{clk}}), .rst({WIDTH{rst}}));

endmodule

`default_nettype wire // Reset default behavior at the end