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
    input string wb_msg,               // Message from the write-back stage
    input logic I_cache_stall,         // Stall signal to indicate pipeline pause for ICACHE miss
    input logic D_cache_stall,         // Stall signal to indicate pipeline pause for ICACHE miss
    input logic normal_stall,         // Stall signal to indicate pipeline pause for LW/SW/B/BR
    input logic hlt                    // Halt signal to indicate CPU halt
);

    ///////////////////////////////////
    // Declare any internal signals //
    /////////////////////////////////
    integer fetch_id, decode_id, execute_id, memory_id, wb_id, msg_index;               // IDs for each stage.
    logic cap_stall, cap_I_cache_stall, cap_D_cache_stall, cap_normal_stall;            // Flag to indicate to capture stall messages in the pipeline.
    logic valid_fetch, valid_decode, valid_execute, valid_memory, valid_wb, print_done; // Valid signals for each stage.
    logic fetched_last;                                                                 // Indicates we fetched the instruction past the HLT instruction.
    debug_info_t pipeline_msgs[0:65535];                                                // Array to hold debug messages for each instruction.

    // Tracks the pipeline and increments IDs.
    always @(posedge clk) begin
      if (!rst_n) begin
          fetch_id <= 0;
          decode_id <= 0;
          execute_id <= 0;
          memory_id <= 0;
          wb_id <= 0;
      end else if (cap_stall && !cap_D_cache_stall) begin
          execute_id <= decode_id;  // Pass the decode_id to execute_id
          memory_id <= execute_id;  // Pass the execute_id to memory_id
          wb_id <= memory_id;       // Pass the memory_id to wb_id
      end else if (!cap_stall && !cap_D_cache_stall) begin
          fetch_id <= fetch_id + 1'b1;  // Increment fetch ID for this cycle.
          decode_id <= fetch_id;    // Pass the fetch_id to decode_id
          execute_id <= decode_id;  // Pass the decode_id to execute_id
          memory_id <= execute_id;  // Pass the execute_id to memory_id
          wb_id <= memory_id;       // Pass the memory_id to wb_id
      end
    end


    // Propagate the valid signals across stages.
    always @(posedge clk) begin
        if (!rst_n) begin
            valid_fetch   <= 0;
            valid_decode  <= 0;
            valid_execute <= 0;
            valid_memory  <= 0;
            valid_wb      <= 0;

        end else if (hlt) begin
            valid_wb <= 1;

        end else begin
            // Default propagation from previous stage.
            valid_decode  <= valid_fetch;
            valid_execute <= valid_decode;
            valid_memory  <= valid_execute;
            valid_wb      <= valid_memory;

            // Stall priority: D-cache > normal > I-cache > normal flow
            if (D_cache_stall) begin
                if (!cap_D_cache_stall) begin
                    // First cycle of D-cache stall: stall all but WB
                    valid_fetch   <= 0;
                    valid_decode  <= 0;
                    valid_execute <= 0;
                    valid_memory  <= 0;
                end

                if (!cap_I_cache_stall) begin
                    // First I-cache stall: freeze fetch
                    valid_fetch <= 0;
                end else begin

                if (!cap_normal_stall) begin
                    // First normal stall: freeze fetch and decode
                    valid_fetch  <= 0;
                    valid_decode <= 0;
                end else begin
                    // Continued normal stall: freeze fetch, decode, execute
                    valid_fetch   <= 0;
                    valid_decode  <= 0;
                    valid_execute <= 0;
                end
                end else begin
                    // Continued D-cache stall: stall all
                    valid_fetch   <= 0;
                    valid_decode  <= 0;
                    valid_execute <= 0;
                    valid_memory  <= 0;
                    valid_wb      <= 0;
                end
            end else if (normal_stall) begin
                if (!cap_normal_stall) begin
                    // First normal stall: freeze fetch and decode
                    valid_fetch  <= 0;
                    valid_decode <= 0;
                end else begin
                    // Continued normal stall: freeze fetch, decode, execute
                    valid_fetch   <= 0;
                    valid_decode  <= 0;
                    valid_execute <= 0;
                end
            end else if (I_cache_stall) begin
                if (!cap_I_cache_stall) begin
                    // First I-cache stall: freeze fetch
                    valid_fetch <= 0;
                end else begin
                    // Continued I-cache stall: freeze fetch and decode
                    valid_fetch  <= 0;
                    valid_decode <= 0;
                end

            end else begin
                // Normal operation
                valid_fetch <= 1;
            end
        end
    end


    // This block is responsible for managing the message index on a stall.
    always @(posedge clk) begin
      if (!rst_n) begin
          msg_index <= 0;
      end else if (!cap_stall) begin
          msg_index <= 0; // Reset when no stall
      end else if (cap_stall) begin
          msg_index <= (msg_index + 1) % 50; // Increment only on stall
      end
    end


    // We must capture stall messages if either stall is active.
    assign cap_stall = cap_normal_stall || cap_I_cache_stall || cap_D_cache_stall;


    // Handles the stall signal and sets the cap_I_cache_stall flag.
    always @(posedge clk) begin
      if (!rst_n) begin
         cap_I_cache_stall <= 1'b0;
      end else if (!I_cache_stall) begin
          cap_I_cache_stall <= 1'b0; // Reset when no stall
      end else if (I_cache_stall) begin
          cap_I_cache_stall <= 1'b1; // Set only on stall
      end
    end


    // Handles the stall signal and sets the cap_I_cache_stall flag.
    always @(posedge clk) begin
      if (!rst_n) begin
         cap_D_cache_stall <= 1'b0;
      end else if (!D_cache_stall) begin
          cap_D_cache_stall <= 1'b0; // Reset when no stall
      end else if (D_cache_stall) begin
          cap_D_cache_stall <= 1'b1; // Set only on stall
      end
    end

    
    // Handles the stall signal and sets the cap_normal_stall flag.
    always @(posedge clk) begin
      if (!rst_n) begin
         cap_normal_stall <= 1'b0;
      end else if (!normal_stall) begin
          cap_normal_stall <= 1'b0; // Reset when no stall
      end else if (normal_stall) begin
          cap_normal_stall <= 1'b1; // Set only on stall
      end
    end


    // Adds the messages from each stage to the pipeline_msgs array.
    always @(negedge clk) begin
      if (rst_n) begin
          if (valid_fetch || cap_I_cache_stall || cap_normal_stall) begin
              pipeline_msgs[fetch_id].fetch_msgs[msg_index] = fetch_msg;
          end
          if (valid_decode || cap_normal_stall || cap_D_cache_stall) begin
              pipeline_msgs[decode_id].decode_msgs[msg_index] = decode_msg;
              pipeline_msgs[decode_id].instr_full_msg = instruction_full_msg;
          end
          if (valid_execute || cap_D_cache_stall) begin
              pipeline_msgs[execute_id].execute_msgs[msg_index] = execute_msg;
          end
          if (valid_memory || cap_D_cache_stall) begin
              pipeline_msgs[memory_id].memory_msgs[msg_index] = mem_msg;
          end
          if (valid_wb) begin
              pipeline_msgs[wb_id].wb_msg = wb_msg;
          end
      end
    end


    // This block is responsible for setting the print_done signal.
    always @(posedge clk) begin
        if (!rst_n) begin
            print_done <= 1'b0; // Reset print_done on reset
        end else if (valid_wb) begin
            print_done <= 1'b1; // Set print_done when valid_wb is high
        end else begin
            print_done <= 1'b0; // Reset otherwise
        end
    end


    // Print the messages when the instruction is in the write-back stage.
    always @(posedge clk) begin
        if (valid_wb) begin
            $display("==========================================================");
            $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline_msgs[wb_id].instr_full_msg, ($time / 10) - 1);
            $display("==========================================================");

            // Print the fetch messages.
            for (int j = 0; j < 50; j = j+1)
                    if (pipeline_msgs[wb_id].fetch_msgs[j] !== "")
                        $display("%s", pipeline_msgs[wb_id].fetch_msgs[j]);

            // Print the decode messages.
            for (int j = 0; j < 50; j = j+1)
                if (pipeline_msgs[wb_id].decode_msgs[j] !== "")
                    $display("%s", pipeline_msgs[wb_id].decode_msgs[j]);
            
            // Print the execute messages.
            for (int j = 0; j < 50; j = j+1)
                if (pipeline_msgs[wb_id].execute_msgs[j] !== "")
                    $display("%s", pipeline_msgs[wb_id].execute_msgs[j]);

            // Print the memory messages.
            for (int j = 0; j < 50; j = j+1)
                if (pipeline_msgs[wb_id].memory_msgs[j] !== "")
                    $display("%s", pipeline_msgs[wb_id].memory_msgs[j]);


            $display("%s", pipeline_msgs[wb_id].wb_msg);
            $display("==========================================================\n");
        end
    end

endmodule