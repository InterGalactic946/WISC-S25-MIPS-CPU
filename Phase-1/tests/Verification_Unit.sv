///////////////////////////////////////////////////////////
// Verification_Unit.sv: Verification Unit Module        //  
//                                                       //
// This module is responsible for verifying and          //
// displaying debug messages for each instruction in     //
// the CPU pipeline stages. It tracks the instruction's  //
// journey through the fetch, decode, execute, memory,   //
// and write-back stages. The module also stores debug   //
// messages at each stage and prints the full pipeline   //
// information when the instruction reaches the          //
// write-back stage. This helps in debugging and         //
// ensuring correct operation of the CPU's pipeline.     //
///////////////////////////////////////////////////////////

  // Importing task library.
  import Monitor_tasks::*;

  module Verification_Unit (
    input logic clk,                   // Clock signal
    input logic rst_n,                 // Active-low reset signal
    input string fetch_msg,            // Message from the fetch stage
    input string decode_msg,           // Message from the decode stage
    input string instruction_full_msg, // Complete decoded instruction in ASM format
    input string execute_msg,          // Message from the execute stage
    input string mem_msg,              // Message from the memory stage
    input string wb_msg                // Message from the write-back stage
);

    ///////////////////////////////////
    // Declare any internal signals //
    /////////////////////////////////
    integer fetch_id;                     // IDs for each instruction.
    logic valid_fetch;                    // Indicates we fetched a valid instruction.
    debug_info_t pipeline_msgs[0:65535];  // Array to hold debug messages for each instruction.

    // Tracks the pipeline and increments IDs.
    always_ff @(posedge clk)
      if (!rst_n)
          fetch_id <= 0;
      else 
        fetch_id <= fetch_id + 1;


    // Propagate the valid signals across stages.
    always_ff @(posedge clk)
        if (!rst_n)
            valid_fetch <= 0;
        else
            valid_fetch <= 1;


    // Adds the messages from each stage to the pipeline_msgs array.
    always @(negedge clk) begin
      if (rst_n) begin
          if (valid_fetch) begin
              pipeline_msgs[fetch_id].fetch_msg = fetch_msg;
              pipeline_msgs[fetch_id].decode_msg = decode_msg;
              pipeline_msgs[fetch_id].instr_full_msg = instruction_full_msg;
              pipeline_msgs[fetch_id].execute_msg = execute_msg;
              pipeline_msgs[fetch_id].memory_msg = mem_msg;
              pipeline_msgs[fetch_id].wb_msg = wb_msg;
          end
      end
    end


    // Print the messages when the instruction is in the write-back stage.
    always_ff @(posedge clk) begin
        if (rst_n) begin
            if (valid_fetch) begin
                $display("==========================================================");
                $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline_msgs[fetch_id].instr_full_msg, ($time / 10) - 1);
                $display("==========================================================");

                $display("%s", pipeline_msgs[fetch_id].fetch_msg);
                $display("%s", pipeline_msgs[fetch_id].decode_msg);
                $display("%s", pipeline_msgs[fetch_id].execute_msg);
                $display("%s", pipeline_msgs[fetch_id].memory_msg);
                $display("%s", pipeline_msgs[fetch_id].wb_msg);
                $display("==========================================================\n");
            end
        end
    end

endmodule