`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////////////
// BitCell.v: Single Bit Memory Cell (Flip-Flop)           //
//                                                         //
// This module implements a single bit memory cell (flip-  //
// flop) with separate read and write enables. It allows   //
// data to be written when the `WriteEnable` signal is     //
// asserted, and provides two read paths through           //
// `ReadEnable1` and `ReadEnable2`. The outputs are        //
// driven to `Bitline1` and `Bitline2` when the read       //
// enables are active, otherwise they are placed in a      //
// high-impedance state (`Z`).                             //
/////////////////////////////////////////////////////////////
module BitCell(clk, rst, D, WriteEnable, ReadEnable1, ReadEnable2, Bitline1, Bitline2);
  
  input wire clk, rst;                 // system clock and active high synchronous reset inputs
  input wire D;                        // data input to the flop
  input wire WriteEnable;              // used to enable writing to a flop
  input wire ReadEnable1, ReadEnable2; // enables reads from a flop through two read paths
  inout wire Bitline1, Bitline2;       // read outputs of a flop driven by tristate driver

  ////////////////////////////////////////////////
  // Declare any internal signals as type wire //
  //////////////////////////////////////////////
  wire Q_output; // Output of the DFF.
  /////////////////////////////////////////////
  
  ///////////////////////////////////////////////////////
  // Implement BitCell as structural/dataflow verilog //
  /////////////////////////////////////////////////////
  // Instantiate the DFF comprising the BitCell.
  dff iDFF (.clk(clk), .rst(rst), .d(D), .q(Q_output), .wen(WriteEnable));

  // Read out on the first bitline when the first read enable is high.
  assign Bitline1 = (ReadEnable1) ? Q_output : 1'bz;
  
  // Read out on the second bitline when the second read enable is high.
  assign Bitline2 = (ReadEnable2) ? Q_output : 1'bz;
	
endmodule

`default_nettype wire  // Reset default behavior at the end