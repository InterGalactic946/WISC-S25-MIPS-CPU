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

import Monitor_tasks::*;

module Verification_Unit (
    input logic clk, rst,
    input string fetch_msg,
    input string decode_msg,
    input string instruction_full_msg,
    input string execute_msg,
    input string mem_msg,
    input string wb_msg,
    input logic stall, flush
    );

    integer fetch_id, decode_id, execute_id, memory_id, wb_id, msg_index;
    logic cap_stall;
    integer fetch_msg_id[0:71], decode_msg_id[0:71];
    logic valid_fetch, valid_decode, valid_execute, valid_memory, valid_wb, print_enable;
    debug_info_t pipeline_msgs[0:71];

// First Always Block: Tracks the pipeline and increments IDs
always @(posedge clk) begin
    if (rst) begin
        fetch_id <= 0;
        decode_id <= 0;
        execute_id <= 0;
        memory_id <= 0;
        wb_id <= 0;
    end else if (cap_stall) begin
        // Only let the execute, mem, and wb stages propogate
        memory_id <= execute_id; // Pass the execute_id to memory_id
        wb_id <= memory_id;      // Pass the memory_id to wb_id
    end else begin
        // Only increment fetch_id when there's no stall.
        fetch_id <= fetch_id + 1;
        // Update pipeline stages.
        decode_id <= fetch_id;   // Pass the fetch_id to decode_id
        execute_id <= decode_id; // Pass the decode_id to execute_id
        memory_id <= execute_id; // Pass the execute_id to memory_id
        wb_id <= memory_id;      // Pass the memory_id to wb_id
    end
end

always @(posedge clk) begin
    if (rst) begin
        msg_index <= 0;
    end else if (!cap_stall) begin
        msg_index <= 0; // Reset when no stall
    end else if (cap_stall) begin
        msg_index <= (msg_index + 1) % 5; // Increment only on stall
    end
end


always @(posedge clk) begin
    if (rst) begin
        cap_stall <= 1'b0;
    end else if (!stall) begin
        cap_stall <= 1'b0; // Reset when no stall
    end else if (stall) begin
        cap_stall <= 1'b1; // Set only on stall
    end
end

// Second Always Block: Propagate the valid signals across stages
always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid_fetch <= 0;
        valid_decode <= 0;
        valid_execute <= 0;
        valid_memory <= 0;
        valid_wb <= 0;
    end else if (flush) begin
        // Clear all valid signals on a flush
        valid_fetch <= 0;
        valid_decode <= 0;
        valid_execute <= 0;
        valid_memory <= 0;
        valid_wb <= 0;
    end else if (!stall) begin
        // Normal operation: propagate valid signals to the next stage
        valid_fetch <= 1;
        valid_decode <= valid_fetch;
        valid_execute <= valid_decode;
        valid_memory <= valid_execute;
        valid_wb <= valid_memory;
    end
    // No else case for stall: hold the previous values (signals remain unchanged)
end


    // Adds the messages, with stall and flush checks.
    always @(negedge clk) begin
        if (!rst) begin
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
        if (valid_wb) begin
            $display("==========================================================");
            $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline_msgs[wb_id].instr_full_msg, $time / 10);
            $display("==========================================================");
            
            for (int j = 0; j < 5; j = j+1)
                    if (pipeline_msgs[wb_id].fetch_msgs[j] !== "")
                        $display("%s", pipeline_msgs[wb_id].fetch_msgs[j]);
               
            for (int j = 0; j < 5; j = j+1)
                    if (pipeline_msgs[wb_id].decode_msgs[j] !== "")
                        $display("%s", pipeline_msgs[wb_id].decode_msgs[j]);

            $display("%s", pipeline_msgs[wb_id].execute_msg);
            $display("%s", pipeline_msgs[wb_id].memory_msg);
            $display("%s", pipeline_msgs[wb_id].wb_msg);
            $display("==========================================================\n");
        end
    end

endmodule
