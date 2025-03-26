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

    integer fetch_id, decode_id, execute_id, memory_id, wb_id, msg_index, max_index;
    integer fetch_msg_id[0:71], decode_msg_id[0:71];
    logic valid_fetch, valid_decode, print, valid_execute, valid_memory, valid_wb, print_enable;
    debug_info_t pipeline_msgs[0:71];

always @(negedge clk) begin
    if (rst) begin
        fetch_id   <= 0;
        decode_id  <= 0;
        execute_id <= 0;
        memory_id  <= 0;
        wb_id      <= 0;
    end else if (valid_fetch) begin
        fetch_id   <= fetch_id + 1;
    end

    decode_id  <= fetch_id;
    execute_id <= decode_id;
    memory_id  <= execute_id;
    wb_id      <= memory_id;
end

always @(negedge clk) begin
    if (rst)
        msg_index <= 1;
    else if (stall)
        msg_index <= msg_index + 1;
end

always @(negedge clk) begin
    if (rst) begin
        valid_decode  <= 0;
        valid_execute <= 0;
        valid_memory  <= 0;
        valid_fetch   <= 1;
        valid_wb      <= 0;
    end else if (!stall) begin
        valid_fetch   <= 1;
    end else if (stall) begin
        valid_fetch   <= 0;
    end

    valid_decode  <= valid_fetch;
    valid_execute <= valid_decode;
    valid_memory  <= valid_execute;
    valid_wb      <= valid_memory;
end

always @(negedge clk) begin
    if (!rst) begin
        if (valid_fetch && !stall) begin
            pipeline_msgs[fetch_id].fetch_msgs[0]  <= fetch_msg;
            pipeline_msgs[fetch_id].fetch_cycles[0] <= $time / 10;
        end else if (stall && !valid_fetch) begin
            pipeline_msgs[fetch_id].fetch_msgs[msg_index]  <= fetch_msg;
            pipeline_msgs[fetch_id].fetch_cycles[msg_index] <= $time / 10;
        end

        if (valid_decode && !stall) begin
            pipeline_msgs[decode_id].decode_msgs[0][0] <= decode_msg;
            pipeline_msgs[decode_id].decode_msgs[0][1] <= instruction_full_msg;
            pipeline_msgs[decode_id].decode_cycles[0] <= $time / 10;
        end else if (!valid_decode && stall) begin
            pipeline_msgs[decode_id].decode_msgs[msg_index][0] <= decode_msg;
            pipeline_msgs[decode_id].decode_msgs[msg_index][1] <= instruction_full_msg;
            pipeline_msgs[decode_id].decode_cycles[msg_index] <= $time / 10;
        end

        if (valid_execute) begin
            pipeline_msgs[execute_id].execute_msg  <= execute_msg;
            pipeline_msgs[execute_id].execute_cycle <= $time / 10;
        end
        if (valid_memory) begin
            pipeline_msgs[memory_id].memory_msg  <= mem_msg;
            pipeline_msgs[memory_id].memory_cycle <= $time / 10;
        end
        if (valid_wb) begin
            pipeline_msgs[wb_id].wb_msg  <= wb_msg;
            pipeline_msgs[wb_id].wb_cycle <= $time / 10;
        end
    end
end

always @(negedge clk) begin
    if (rst)
        print <= 1'b0;
    else if (valid_wb)
        print <= 1'b1;
    else
        print <= 1'b0;
end

always @(posedge clk) begin
    if (print) begin
        max_index = 0;
        for (int i = 0; i < 5; i = i + 1) begin
            if (pipeline_msgs[wb_id].decode_msgs[i][1] !== "")
                max_index = max_index + 1;
        end
        $display("==========================================================");
        $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline_msgs[wb_id].decode_msgs[max_index][1], $time / 10);
        $display("==========================================================");
        
        max_index = 0;
        for (int i = 0; i < 5; i = i + 1) begin
            if (pipeline_msgs[wb_id].fetch_msgs[i] !== "")
                max_index = max_index + 1;
        end
        for (int i = 0; i < 5; i = i+1)
            if (pipeline_msgs[wb_id].fetch_msgs[i] !== "")
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].fetch_msgs[i], pipeline_msgs[wb_id].fetch_cycles[i]);
        for (int i = 0; i < 5; i = i+1)
            if (pipeline_msgs[wb_id].decode_msgs[i][0] !== "")
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].decode_msgs[i][0], pipeline_msgs[wb_id].decode_cycles[i]);
        $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].execute_msg, pipeline_msgs[wb_id].execute_cycle);
        $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].memory_msg, pipeline_msgs[wb_id].memory_cycle);
        $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].wb_msg, pipeline_msgs[wb_id].wb_cycle);
        $display("==========================================================\n");
    end
end
endmodule