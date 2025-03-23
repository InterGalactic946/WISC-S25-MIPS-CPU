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
    input logic clk, rst,                  // Clock and rst 
    input string fetch_msg,                // Fetch stage message
    input string if_id_msg,                // IF/ID Register message
    input string decode_msg,               // Decode stage messages
    input string instruction_full_msg,     // Full instruction message
    input string id_ex_message,            // ID/EX Register message
    input string execute_msg,              // Execute stage message
    input string ex_mem_message,           // EX/MEM Register message
    input string mem_verify_msg,           // Memory stage message
    input string mem_wb_message,           // MEM/WB Register message
    input string wb_verify_msg,            // Write-back stage message,
    input string pc_message,               // PC_stall message
    input string if_id_hz_message,         // IF_ID stall message
    input string id_ex_hz_message,         // ID_EX stall message
    input string flush_message,            // Flush message

    input logic stall, flush, 
    input logic IF_flush, ID_flush         // stall/flsuh signals of the CPU
);

    ///////////////////////////////////
    // Declare any internal signals //
    /////////////////////////////////
    integer fetch_id;                 // Fetch instruction ID
    integer decode_id;                // Decode instruction ID
    integer execute_id;               // Execute instruction ID
    integer memory_id;                // Memory instruction ID
    integer wb_id;                    // Write back instruction ID
    integer pc_idx;
    integer if_id_idx;
    integer id_ex_idx;
    debug_info_t pipeline_msgs[0:71]; // Array to store debug messages for each instruction (assuming 72 instructions)
    //////////////////////////////////

    // Keep track of all instructions in the pipeline.
    always @(posedge clk) begin
        if (rst) begin
            // Reset the pipeline indices
            fetch_id  <= -1;
            decode_id <= -2;
            execute_id <= -3;
            memory_id  <= -4;
            wb_id <= -5;

            pc_idx <= 0;
            if_id_idx <= 0;
            id_ex_idx <= 0;
        end else begin
            // Fetch Stage
            if (fetch_id >= 0) begin
                pipeline_msgs[fetch_id].pc_message[pc_idx] <= pc_message;
                pipeline_msgs[fetch_id].fetch_msg <= fetch_msg;
                pipeline_msgs[fetch_id].fetch_cycle <= $time / 10;
            end

            // Decode Stage (IF/ID pipeline register & decode)
            if (decode_id >= 0) begin
                pipeline_msgs[decode_id].if_id_hz_message[if_id_idx] <= if_id_hz_message;
                pipeline_msgs[decode_id].flush_message[if_id_idx] <= flush_message;
                pipeline_msgs[decode_id].decode_msg[0] <= decode_msg;
                pipeline_msgs[decode_id].decode_msg[1] <= instruction_full_msg;
                pipeline_msgs[decode_id].if_id_msg   <= if_id_msg;
                pipeline_msgs[decode_id].if_id_cycle <= $time / 10;
                pipeline_msgs[decode_id].decode_cycle  <= $time / 10;
            end

            // Execute Stage (ID/EX pipeline register & execute)
            if (execute_id >= 0) begin
                pipeline_msgs[execute_id].id_ex_hz_message[id_ex_idx] <= if_id_hz_message;
                pipeline_msgs[execute_id].flush_message[id_ex_idx] <= flush_message;
                pipeline_msgs[execute_id].id_ex_msg   <= id_ex_message;
                pipeline_msgs[execute_id].execute_msg   <= execute_msg;
                pipeline_msgs[execute_id].id_ex_cycle <= $time / 10;
                pipeline_msgs[execute_id].execute_cycle <= $time / 10;
            end

            // Memory Stage (EX/MEM pipeline register & memory)
            if (memory_id >= 0) begin
                pipeline_msgs[memory_id].ex_mem_msg   <= ex_mem_message;
                pipeline_msgs[memory_id].ex_mem_cycle <= $time / 10;
                pipeline_msgs[memory_id].memory_msg   <= mem_verify_msg;
                pipeline_msgs[memory_id].memory_cycle <= $time / 10;
            end

            // Write-Back Stage (MEM/WB pipeline register & write-back)
            if (wb_id >= 0) begin
                pipeline_msgs[wb_id].mem_wb_msg   = mem_wb_message;
                pipeline_msgs[wb_id].mem_wb_cycle = $time / 10;

                pipeline_msgs[wb_id].wb_msg   = wb_verify_msg;
                pipeline_msgs[wb_id].wb_cycle = $time / 10;

                // Print all messages for this instruction when it reaches WB.
                $display("=====================================================");
                $display("| Instruction: %s | Clock Cycle: %0t |", pipeline_msgs[wb_id].decode_msg[1], $time/10);
                $display("=====================================================");
                
                if (stall)
                    print_stall_messages(.inst_id(wb_id), .size(pc_idx), .msg_type("pc"), .cycle(pipeline_msgs[wb_id].fetch_cycle));
                else 
                    $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].fetch_msg, pipeline_msgs[wb_id].fetch_cycle);
                
                if (stall)
                    print_stall_messages(.inst_id(wb_id), .size(if_id_idx), .msg_type("if_id"), .cycle(pipeline_msgs[wb_id].if_id_cycle));
                else if (flush)
                    print_stall_messages(.inst_id(wb_id), .size(if_id_idx), .msg_type("flush"), .cycle(pipeline_msgs[wb_id].if_id_cycle));
                else begin
                    $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].if_id_msg, pipeline_msgs[wb_id].if_id_cycle);
                    $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].decode_msg[0], pipeline_msgs[wb_id].decode_cycle);
                end

                if (stall)
                    print_stall_messages(.inst_id(wb_id), .size(id_ex_idx), .msg_type("id_ex"), .cycle(pipeline_msgs[wb_id].id_ex_cycle));
                else if (flush)
                    print_stall_messages(.inst_id(wb_id), .size(id_ex_idx), .msg_type("flush"), .cycle(pipeline_msgs[wb_id].id_ex_cycle));
                else begin
                    $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].id_ex_msg, pipeline_msgs[wb_id].id_ex_cycle);
                end

                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].execute_msg, pipeline_msgs[wb_id].execute_cycle);
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].ex_mem_msg, pipeline_msgs[wb_id].ex_mem_cycle);
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].memory_msg, pipeline_msgs[wb_id].memory_cycle);
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].mem_wb_msg, pipeline_msgs[wb_id].mem_wb_cycle);
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].wb_msg, pipeline_msgs[wb_id].wb_cycle);
                $display("=====================================================\n");
            end

            // Move all stage indices forward if not stalling or flushing.
            if (!(stall || flush)) begin
                fetch_id  <= fetch_id + 1;
                decode_id <= decode_id + 1;
                execute_id <= execute_id + 1;
                memory_id  <= memory_id + 1;
                wb_id <= wb_id + 1;
            end else if (stall || flush)
                pc_idx <= pc_idx + 1;
                if_id_idx <= if_id_idx + 1;
                id_ex_idx <= id_ex_idx + 1;
        end
    end

    // Task: Prints the stall and flush messages.
    task automatic print_stall_messages(input integer inst_id, integer size, input string msg_type, integer cycle);
        integer i;
        for (i = 0; i < size; i++) begin
            if (msg_type == "pc" && pipeline_msgs[inst_id].pc_message[i] != "")
                $display("|%s @ Cycle: %0t", pipeline_msgs[inst_id].pc_message[i], cycle);
            else if (msg_type == "if_id" && pipeline_msgs[inst_id].if_id_hz_message[i] != "")
                $display("|%s @ Cycle: %0t", pipeline_msgs[inst_id].if_id_hz_message[i], cycle);
            else if (msg_type == "id_ex" && pipeline_msgs[inst_id].id_ex_hz_message[i] != "")
                $display("|%s @ Cycle: %0t", pipeline_msgs[inst_id].id_ex_hz_message[i], cycle);
            else if (msg_type == "flush" && pipeline_msgs[inst_id].flush_message[i] != "")
                $display("|%s @ Cycle: %0t", pipeline_msgs[inst_id].flush_message[i], cycle);
        end
    endtask
endmodule
