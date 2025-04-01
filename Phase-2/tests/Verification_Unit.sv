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
    input logic stall,                 // Stall signal to indicate pipeline pause
    input logic hlt                    // Halt signal to indicate CPU halt
);

    ///////////////////////////////////
    // Declare any internal signals //
    /////////////////////////////////
    integer fetch_id, decode_id, execute_id, memory_id, wb_id, msg_index;               // IDs for each stage.
    logic cap_stall;                                                                    // Flag to indicate to capture stall messages in the pipeline.
    logic valid_fetch, valid_decode, valid_execute, valid_memory, valid_wb, print_done; // Valid signals for each stage.
    debug_info_t pipeline_msgs[0:71];                                                   // Array to hold debug messages for each instruction.

    // Tracks the pipeline and increments IDs.
    always @(posedge clk) begin
      if (!rst_n) begin
          fetch_id <= 0;
          decode_id <= 0;
          execute_id <= 0;
          memory_id <= 0;
          wb_id <= 0;
      end else if (cap_stall) begin
          /* Only let the execute, mem, and wb stages propogate. */
          execute_id <= decode_id; // Pass the decode_id to execute_id
          memory_id <= execute_id; // Pass the execute_id to memory_id
          wb_id <= memory_id;      // Pass the memory_id to wb_id
      end else begin
          fetch_id <= fetch_id + 1; // Only increment fetch_id when there's no stall.
          decode_id <= fetch_id;    // Pass the fetch_id to decode_id
          execute_id <= decode_id;  // Pass the decode_id to execute_id
          memory_id <= execute_id;  // Pass the execute_id to memory_id
          wb_id <= memory_id;       // Pass the memory_id to wb_id
      end
    end

    // Propagate the valid signals across stages.
    always @(posedge clk) begin
        if (!rst_n) begin
            valid_fetch <= 0;
            valid_decode <= 0;
            valid_execute <= 0;
            valid_memory <= 0;
            valid_wb <= 0;
        end else if (!stall) begin
            // Case 1: No stall (normal operation).
            if (!cap_stall) begin
                // Previous cycle was not stalled, propagate valid signals normally.
                valid_fetch <= 1;
                valid_decode <= valid_fetch;
                valid_execute <= valid_decode;
                valid_memory <= valid_execute;
                valid_wb <= valid_memory;
            end else begin
                // Case 2: No stall in current cycle, but previous cycle was stalled.
                // Hold the valid signals for the stages that were stalled.
                valid_fetch <= 1;  // Fetch can proceed.
                valid_decode <= 1; // Decode can proceed, since fetch was valid last cycle.
                valid_execute <= valid_decode;  // Execute propagates from decode.
                valid_memory <= valid_execute;  // Memory propagates from execute.
                valid_wb <= valid_memory;       // WB propagates from memory.
            end
        end else if (stall) begin
            // Case 3: Stall condition (current cycle stalled).
            if (!cap_stall) begin
                // First stall: freeze fetch and decode, propagate others.
                valid_fetch <= 0;
                valid_decode <= 0;
                valid_execute <= valid_decode; // Continue valid from decode.
                valid_memory <= valid_execute; // Continue valid from execute.
                valid_wb <= valid_memory;      // Continue valid from memory.
            end else begin
                // Continued stall (previous cycle was stalled).
                // If hlt is set, we make sure to set the valid_wb signal to 1.
                if (hlt) begin
                    valid_wb <= 1;
                end else begin
                    // Freeze fetch, decode, and execute, propagate memory and wb.
                    valid_fetch <= 0;
                    valid_decode <= 0;
                    valid_execute <= 0;
                    valid_memory <= valid_execute; // Continue valid from execute.
                    valid_wb <= valid_memory;      // Continue valid from memory.
                end
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
          msg_index <= (msg_index + 1) % 5; // Increment only on stall
      end
    end


    // Handles the stall signal and sets the cap_stall flag.
    always @(posedge clk) begin
      if (!rst_n) begin
         cap_stall <= 1'b0;
      end else if (!stall) begin
          cap_stall <= 1'b0; // Reset when no stall
      end else if (stall) begin
          cap_stall <= 1'b1; // Set only on stall
      end
    end


    // Adds the messages from each stage to the pipeline_msgs array.
    always @(negedge clk) begin
      if (rst_n) begin
          if (valid_fetch || cap_stall) begin
              pipeline_msgs[fetch_id].fetch_msgs[msg_index] = fetch_msg;
          end
          if (valid_decode || cap_stall) begin
              pipeline_msgs[decode_id].decode_msgs[msg_index] = decode_msg;
              pipeline_msgs[decode_id].instr_full_msg = instruction_full_msg;
          end
          if (valid_execute) begin
              pipeline_msgs[execute_id].execute_msg = execute_msg;
          end
          if (valid_memory) begin
              pipeline_msgs[memory_id].memory_msg = mem_msg;
          end
          if (valid_wb) begin
              pipeline_msgs[wb_id].wb_msg = wb_msg;
          end
      end
    end


    // Print the message for each instruction.
    always @(posedge clk) begin
      if (!rst_n)
        print_done <= 1'b0; // Reset the print_done flag on reset
      else  if (valid_wb) begin
            $display("==========================================================");
            $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline_msgs[wb_id].instr_full_msg, ($time / 10) - 1);
            $display("==========================================================");
                
            for (int j = 0; j < 5; j = j+1)
                    if (pipeline_msgs[wb_id].fetch_msgs[j] !== "")
                        $display("%s", pipeline_msgs[wb_id].fetch_msgs[j]);
                            
            for (int j = 0; j < 5; j = j+1)
                    if (pipeline_msgs[wb_id].decode_msgs[j] !== "")
                        $display("%s", pipeline_msgs[wb_id].decode_msgs[j]);

            // Don't print execute, memory, and wb messages if the instruction is HLT.
            if (pipeline_msgs[wb_id].instr_full_msg !== "HLT") begin
                $display("%s", pipeline_msgs[wb_id].execute_msg);
                $display("%s", pipeline_msgs[wb_id].memory_msg);
                $display("%s", pipeline_msgs[wb_id].wb_msg);
            end
            $display("==========================================================\n");

            print_done <= 1'b1; // Set the print_done flag to true after printing
    end else begin
            print_done <= 1'b0; // Reset the print_done flag when not in write-back stage
        end
   end

endmodule