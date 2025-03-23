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
    input logic clk, rst,                  // Clock and reset signals
    input string fetch_msg,                // Fetch stage message
    input string if_id_msg,                // IF/ID Register message
    input string decode_msg,               // Decode stage message
    input string instruction_full_msg,     // Full instruction message
    input string id_ex_msg,                // ID/EX Register message
    input string execute_msg,              // Execute stage message
    input string ex_mem_msg,               // EX/MEM Register message
    input string mem_msg,                  // Memory stage message
    input string mem_wb_msg,               // MEM/WB Register message
    input string wb_msg,                   // Write-back stage message
    input string pc_msg,                   // PC stall message
    input string if_id_hz_msg,             // IF/ID stall message
    input string id_ex_hz_msg,             // ID/EX stall message
    input string flush_msg,                // Flush message
    input logic stall, flush,              // Stall and flush signals
    input logic IF_flush, ID_flush         // Specific flush signals
);

    // Pipeline tracking IDs
    integer fetch_id, decode_id, execute_id, memory_id, wb_id;
    integer pc_idx, if_id_idx, id_ex_idx;
    debug_info_t pipeline_msgs[0:71]; // Debug message storage for up to 72 instructions

    always @(posedge clk) begin
        if (rst) begin
            fetch_id  <= 0;
            decode_id <= -1;
            execute_id <= -2;
            memory_id  <= -3;
            wb_id <= -4;
            pc_idx <= 0;
            if_id_idx <= 0;
            id_ex_idx <= 0;
        end else begin
            // Fetch Stage
            if (fetch_id >= 1) begin
                pipeline_msgs[fetch_id].pc_msg[pc_idx] <= pc_msg;
                pipeline_msgs[fetch_id].fetch_msg <= fetch_msg;
                pipeline_msgs[fetch_id].fetch_cycle <= $time / 10;
            end

            // Decode Stage
            if (decode_id >= 0) begin
                pipeline_msgs[decode_id].if_id_hz_msg[if_id_idx] <= if_id_hz_msg;
                pipeline_msgs[decode_id].flush_msg[if_id_idx] <= flush_msg;
                pipeline_msgs[decode_id].decode_msg[0] <= decode_msg;
                pipeline_msgs[decode_id].decode_msg[1] <= instruction_full_msg;
                pipeline_msgs[decode_id].if_id_msg <= if_id_msg;
                pipeline_msgs[decode_id].if_id_cycle <= $time / 10;
                pipeline_msgs[decode_id].decode_cycle <= $time / 10;
            end

            // Execute Stage
            if (execute_id >= 0) begin
                pipeline_msgs[execute_id].id_ex_hz_msg[id_ex_idx] <= id_ex_hz_msg;
                pipeline_msgs[execute_id].flush_msg[id_ex_idx] <= flush_msg;
                pipeline_msgs[execute_id].id_ex_msg <= id_ex_msg;
                pipeline_msgs[execute_id].execute_msg <= execute_msg;
                pipeline_msgs[execute_id].id_ex_cycle <= $time / 10;
                pipeline_msgs[execute_id].execute_cycle <= $time / 10;
            end

            // Memory Stage
            if (memory_id >= 0) begin
                pipeline_msgs[memory_id].ex_mem_msg <= ex_mem_msg;
                pipeline_msgs[memory_id].ex_mem_cycle <= $time / 10;
                pipeline_msgs[memory_id].mem_msg <= mem_msg;
                pipeline_msgs[memory_id].mem_cycle <= $time / 10;
            end

            // Write-Back Stage
            if (wb_id >= 0) begin
                pipeline_msgs[wb_id].mem_wb_msg = mem_wb_msg;
                pipeline_msgs[wb_id].mem_wb_cycle = $time / 10;
                pipeline_msgs[wb_id].wb_msg = wb_msg;
                pipeline_msgs[wb_id].wb_cycle = $time / 10;
                print_pipeline_info(wb_id);
            end

            // Update indices
            if (!(stall || flush)) begin
                fetch_id  <= fetch_id + 1;
                decode_id <= decode_id + 1;
                execute_id <= execute_id + 1;
                memory_id  <= memory_id + 1;
                wb_id <= wb_id + 1;
            end else begin
                pc_idx <= pc_idx + 1;
                if_id_idx <= if_id_idx + 1;
                id_ex_idx <= id_ex_idx + 1;
            end
        end
    end

    // Task to print the full pipeline information
    task automatic print_pipeline_info(input integer inst_id);
        $display("=====================================================");
        $display("| Instruction: %s | Clock Cycle: %0t |", pipeline_msgs[inst_id].decode_msg[1], $time/10);
        $display("=====================================================");
        print_stage_info(inst_id, "pc", pipeline_msgs[inst_id].pc_msg, pc_idx);
        print_stage_info(inst_id, "if_id", pipeline_msgs[inst_id].if_id_msg, if_id_idx);
        print_stage_info(inst_id, "decode", pipeline_msgs[inst_id].decode_msg, 2);
        print_stage_info(inst_id, "id_ex", pipeline_msgs[inst_id].id_ex_msg, id_ex_idx);
        print_stage_info(inst_id, "execute", pipeline_msgs[inst_id].execute_msg, 1);
        print_stage_info(inst_id, "memory", pipeline_msgs[inst_id].mem_msg, 1);
        print_stage_info(inst_id, "write-back", pipeline_msgs[inst_id].wb_msg, 1);
        $display("=====================================================");
    endtask

    // Task to print specific stage messages
    task automatic print_stage_info(input integer inst_id, input string stage, input string msg, input integer size);
        integer i;
        for (i = 0; i < size; i++) begin
            if (msg[i] != "")
                $display("| %s: %s @ Cycle: %0t", stage, msg[i], $time / 10);
        end
    endtask
endmodule
