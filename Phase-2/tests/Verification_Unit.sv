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
    input string if_id_msg,
    input string decode_msg,
    input string instruction_full_msg,
    input string id_ex_message,
    input string execute_msg,
    input string ex_mem_message,
    input string mem_verify_msg,
    input string mem_wb_message,
    input string wb_verify_msg,
    input string pc_message,
    input string if_id_hz_message,
    input string id_ex_hz_message,
    input string flush_message,
    input logic stall, flush, 
    input logic IF_flush, ID_flush
);

    integer fetch_id, decode_id, execute_id, memory_id, wb_id;
    logic valid_fetch, valid_decode, valid_execute, valid_memory, valid_wb;
    debug_info_t pipeline_msgs[0:71];

    always @(posedge clk) begin
        if (rst) begin
            fetch_id <= 0;
            decode_id <= 0;
            execute_id <= 0;
            memory_id <= 0;
            wb_id <= 0;
            valid_fetch <= 1; // Ensure first instruction is captured
            valid_decode <= 0;
            valid_execute <= 0;
            valid_memory <= 0;
            valid_wb <= 0;
        end else if (!(stall || flush)) begin
            fetch_id <= fetch_id + 1;
            decode_id <= fetch_id;   // Assign directly to fetch_id
            execute_id <= decode_id; // Assign directly to decode_id
            memory_id <= execute_id; // Assign directly to execute_id
            wb_id <= memory_id;      // Assign directly to memory_id

            valid_decode <= valid_fetch;
            valid_execute <= valid_decode;
            valid_memory <= valid_execute;
            valid_wb <= valid_memory;
        end
    end


    always @(posedge clk) begin
        if (!rst) begin
            if (valid_decode) begin
                pipeline_msgs[decode_id].decode_msg[0] <= decode_msg;
                pipeline_msgs[decode_id].decode_msg[1] <= instruction_full_msg;
                pipeline_msgs[decode_id].if_id_msg <= if_id_msg;
                pipeline_msgs[decode_id].if_id_cycle <= $time / 10;
                pipeline_msgs[decode_id].decode_cycle <= $time / 10;
            end
            if (valid_execute) begin
                pipeline_msgs[execute_id].id_ex_msg <= id_ex_message;
                pipeline_msgs[execute_id].execute_msg <= execute_msg;
                pipeline_msgs[execute_id].id_ex_cycle <= $time / 10;
                pipeline_msgs[execute_id].execute_cycle <= $time / 10;
            end
            if (valid_memory) begin
                pipeline_msgs[memory_id].ex_mem_msg <= ex_mem_message;
                pipeline_msgs[memory_id].ex_mem_cycle <= $time / 10;
                pipeline_msgs[memory_id].memory_msg <= mem_verify_msg;
                pipeline_msgs[memory_id].memory_cycle <= $time / 10;
            end
            if (valid_wb) begin
                pipeline_msgs[wb_id].mem_wb_msg = mem_wb_message;
                pipeline_msgs[wb_id].mem_wb_cycle = $time / 10;
                pipeline_msgs[wb_id].wb_msg = wb_verify_msg;
                pipeline_msgs[wb_id].wb_cycle = $time / 10;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst && valid_wb) begin
            $display("==========================================================");
            $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline_msgs[wb_id].decode_msg[1], $time/10);
            $display("==========================================================");
            $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].if_id_msg, pipeline_msgs[wb_id].if_id_cycle);
            $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].decode_msg[0], pipeline_msgs[wb_id].decode_cycle);
            $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].id_ex_msg, pipeline_msgs[wb_id].id_ex_cycle);
            $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].execute_msg, pipeline_msgs[wb_id].execute_cycle);
            $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].ex_mem_msg, pipeline_msgs[wb_id].ex_mem_cycle);
            $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].memory_msg, pipeline_msgs[wb_id].memory_cycle);
            $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].mem_wb_msg, pipeline_msgs[wb_id].mem_wb_cycle);
            $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].wb_msg, pipeline_msgs[wb_id].wb_cycle);
            $display("==========================================================\n");
        end
    end

endmodule
