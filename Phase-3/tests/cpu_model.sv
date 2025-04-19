///////////////////////////////////////////////////////////
// cpu.sv: Central Processing Unit Module                //  
//                                                       //
// This module represents the CPU, responsible for       //
// fetching, decoding, executing instructions, and       //
// It integrates the processor core with main memory     //
// to facilitate program execution.                      //
///////////////////////////////////////////////////////////
module cpu_model (clk, rst_n, hlt, pc);

  input logic clk;         // System clock
  input logic rst_n;       // Active low synchronous reset
  output logic hlt;        // Asserted once the processor finishes an instruction before a HLT instruction
  output logic [15:0] pc;  // PC value over the course of program execution

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////  
  logic rst;                 // Active-high reset (internal)
  logic mem_wr;              // Memory write enable
  logic mem_en;              // Memory enable
  logic [15:0] mem_addr;     // Address to memory
  logic [15:0] mem_data_in;  // Data to write to memory
  logic [15:0] mem_data_out; // Data read from memory
  logic mem_data_valid;      // Valid signal from memory\
  /////////////////////////////////

  /////////////////////////////////////////
  // Make reset active high for modules //
  ///////////////////////////////////////
  assign rst = ~rst_n;

  /////////////////////////////////////
  // Instantiate the processor core //
  ///////////////////////////////////
  proc_model iPROC (
    .clk(clk),
    .rst(rst),
    
    .mem_data_valid(mem_data_valid),
    .mem_data_out(mem_data_out),
    
    .mem_en(mem_en),
    .mem_addr(mem_addr),
    .mem_wr(mem_wr),
    .mem_data_in(mem_data_in),

    .hlt(hlt),
    .pc(pc)
  );

  //////////////////////////////
  // Instantiate main memory  //
  //////////////////////////////
  memory iMAIN_MEM (
    .clk(clk),
    .rst(rst),
    .enable(mem_en),
    .addr(mem_addr),
    .wr(mem_wr),
    .data_in(mem_data_in),
    
    .data_valid(mem_data_valid),
    .data_out(mem_data_out)
  );

endmodule

`default_nettype wire  // Reset default behavior at the end