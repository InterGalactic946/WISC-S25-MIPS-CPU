`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////////////
// Fetch.v: Instruction Fetch Stage                         //
//                                                          //
// This module implements the instruction fetch stage of    //
// the pipeline. It manages the Program Counter (PC) and    //
// determines the next instruction address using branch     //
// prediction. The module includes logic to choose between  //
// sequential execution (PC + 2) and branch targets based   //
// on predictions from the Branch Predictor.                //
//////////////////////////////////////////////////////////////
module Fetch(clk, rst, stall, Branch_target, Branch_taken, PC_next, PC_inst, PC_curr);
  
  input wire clk;                  // System clock
  input wire rst;                  // Active high synchronous reset
  input wire stall;                // Stall signal for the PC (from the hazard detection unit)
  input wire [15:0] Branch_target; // Computed offset for branch instructions (from the decode stage)
  input wire Branch_taken;         // Signal used to determine whether branch is taken (from the decode stage)
  
  output wire [15:0] PC_next;      // The next PC value
  output wire [15:0] PC_inst;      // Instruction at the current PC address
  output wire [15:0] PC_curr;      // The current PC's value.

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire [15:0] PC_new;  // The new address the PC is updated with.
  wire wen;            // PC write enable signal.
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////
  // Implement PC_control as structural/dataflow verilog //
  ////////////////////////////////////////////////////////
  // We write to the PC whenever we don't stall.
  assign wen = ~stall;

  // Choose between the computed branch target address and (PC+2) to update the PC register.
  assign PC_new = (Branch_taken) ? Branch_target : PC_next;

  // Infer the PC Register.
  CPU_Register iPC (.clk(clk), .rst(rst), .wen(wen), .data_in(PC_new), .data_out(PC_curr));

  // Infer the instruction memory, it is always read enabled and never write enabled.
  memory1c iINSTR_MEM (.data_out(PC_inst),
                       .data_in(16'h0000),
                        .addr(PC_curr),
                        .enable(1'b1),
                        .data(1'b0),
                        .wr(1'b0),
                        .clk(clk),
                        .rst(rst)
                      );

  // Instantiate the PC+2 adder.
  CLA_16bit iCLA_next (.A(PC_curr), .B(16'h0002), .sub(1'b0), .Sum(PC_next), .Cout(), .Ovfl(), .pos_Ovfl(), .neg_Ovfl());

endmodule

`default_nettype wire // Reset default behavior at the end