`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////////
// IF_ID_pipe_reg.v: Instruction Fetch to Decode Pipeline    //
//                                                           //
// This module represents the pipeline register between the  //
// Instruction Fetch (IF) stage and the Instruction Decode   //
// (ID) stage. It holds the Program Counter (PC) and the     //
// fetched instruction while passing them from the IF stage  //
// to the ID stage.                                          //
///////////////////////////////////////////////////////////////
module IF_ID_pipe_reg ( 
    input wire clk,                     // System clock
    input wire rst,                     // Active high synchronous reset
    input wire stall,                   // Stall signal (prevents updates)
    input wire flush,                   // Flush pipeline register (clears the instruction word)
    input wire [15:0] PC_curr,          // Current PC from the fetch stage
    input wire [15:0] PC_next,          // Next PC from the fetch stage
    input wire [4:0] first_tag_LRU,     // LRU tag from instruction cache (used by BTB)
    input wire first_match,             // Whether this tag matched a BTB entry
    input wire hit,                     // Whether the instruction cache had a hit
    input wire [15:0] PC_inst,          // Current instruction word from the fetch stage
    input wire [1:0] prediction,        // The 2-bit predicted value of the current branch instruction from the fetch stage
    input wire [15:0] predicted_target, // The predicted target from the BTB.

    output wire [15:0] IF_ID_PC_curr,           // Pipelined current instruction address passed to the decode stage
    output wire [15:0] IF_ID_PC_next,           // Pipelined next PC passed to the decode stage
    output wire [15:0] IF_ID_PC_inst,           // Pipelined current instruction word passed to the decode stage
    output wire [4:0] IF_ID_first_tag_LRU,      // Pipelined LRU tag to the decode stage
    output wire IF_ID_first_match,              // Pipelined BTB match signal to the decode stage
    output wire IF_ID_ICACHE_hit,               // Pipelined instruction cache hit signal
    output wire [1:0] IF_ID_prediction,         // Pipelined 2-bit branch prediction signal passed to the decode stage
    output wire [15:0] IF_ID_predicted_target   // Pipelined branch prediction target passed to the decode stage
);

  /////////////////////////////////////////////////
  // Declare any internal control signals        //
  /////////////////////////////////////////////////
  wire wen; // Register write enable signal
  wire clr; // Clear signal for flush or reset
  /////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////
  // Write to the register only if there is no stall           //
  ///////////////////////////////////////////////////////////////
  assign wen = ~stall;

  ///////////////////////////////////////////////////////////////
  // Clear the instruction and metadata on flush or reset      //
  ///////////////////////////////////////////////////////////////
  assign clr = flush | rst;

  //////////////////////////////////////////////////////////////////
  // Pipeline current PC from IF stage to ID stage                //
  //////////////////////////////////////////////////////////////////
  CPU_Register iPC_CURR_REG (.clk(clk), .rst(rst), .wen(wen), .data_in(PC_curr), .data_out(IF_ID_PC_curr));
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////
  // Pipeline next PC address from IF stage to ID stage           //
  //////////////////////////////////////////////////////////////////
  CPU_Register iPC_NEXT_REG (.clk(clk), .rst(rst), .wen(wen), .data_in(PC_next), .data_out(IF_ID_PC_next));
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////
  // Pipeline the LRU value of the first tag //
  ////////////////////////////////////////////
  CPU_Register #(.WIDTH(1)) iFIRST_TAG_LRU_REG (.clk(clk), .rst(clr), .wen(wen), .data_in(first_tag_LRU), .data_out(IF_ID_first_tag_LRU));
  ///////////////////////////////////////////

  //////////////////////////////////////
  // Pipeline the first_match signal //
  ////////////////////////////////////
  CPU_Register #(.WIDTH(1)) iFIRST_MATCH_REG (.clk(clk), .rst(clr), .wen(wen), .data_in(first_match), .data_out(IF_ID_first_match));
  ///////////////////////////////////

  //////////////////////////////////////////////////////////////////
  // Pipeline the ICACHE hit signal to the decode stage           //
  //////////////////////////////////////////////////////////////////
  CPU_Register #(.WIDTH(1)) iICACHE_HIT_REG (.clk(clk), .rst(clr), .wen(wen), .data_in(hit), .data_out(IF_ID_ICACHE_hit));
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////
  // Pipeline instruction word from IF stage to ID stage          //
  //////////////////////////////////////////////////////////////////
  CPU_Register iPC_INST_REG (.clk(clk), .rst(clr), .wen(wen), .data_in(PC_inst), .data_out(IF_ID_PC_inst));
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////
  // Pipeline branch prediction bits to the decode stage          //
  //////////////////////////////////////////////////////////////////
  CPU_Register #(.WIDTH(2)) iPREDICTION_REG (.clk(clk), .rst(clr), .wen(wen), .data_in(prediction), .data_out(IF_ID_prediction));
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////
  // Pipeline predicted target address to the decode stage        //
  //////////////////////////////////////////////////////////////////
  CPU_Register iPREDICTED_TARGET_REG (.clk(clk), .rst(clr), .wen(wen), .data_in(predicted_target), .data_out(IF_ID_predicted_target));
  //////////////////////////////////////////////////////////////////


endmodule

`default_nettype wire // Reset default behavior at the end
