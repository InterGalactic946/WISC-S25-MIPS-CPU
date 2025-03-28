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

    integer fetch_id, decode_id, execute_id, memory_id, wb_id;
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
    end else if (valid_fetch) begin
        // Only increment fetch_id when there's a valid fetch.
        fetch_id <= fetch_id + 1;
    end

    // Update pipeline stages.
    decode_id <= fetch_id;   // Pass the fetch_id to decode_id
    execute_id <= decode_id; // Pass the decode_id to execute_id
    memory_id <= execute_id; // Pass the execute_id to memory_id
    wb_id <= memory_id;      // Pass the memory_id to wb_id
end


//     // // Reset or increment the fetch_msg_id and decode_msg_id, based on stall condition
//     // always @(posedge clk) begin
//     //     if (rst) begin
//     //         // Initialize message indices to zero
//     //         fetch_msg_id <= '{default: 0};
//     //         decode_msg_id <= '{default: 0};
//     //     end else begin
//     //         if (stall) begin
//     //             // Increment the fetch and decode message IDs when stall is active
//     //             fetch_msg_id[fetch_id] <= fetch_msg_id[fetch_id] + 1;
//     //             decode_msg_id[decode_id] <= decode_msg_id[decode_id] + 1;
//     //         end else begin
//     //             // Reset message IDs when there's no stall
//     //             if (valid_fetch) begin
//     //                 fetch_msg_id[fetch_id] <= 0;
//     //             end
//     //             if (valid_decode) begin
//     //                 decode_msg_id[decode_id] <= 0;
//     //             end
//     //         end
//     //     end
//     // end


// Second Always Block: Propagate the valid signals across stages
always @(posedge clk) begin
    if (rst) begin
        valid_decode <= 0;
        valid_execute <= 0;
        valid_memory <= 0;
        valid_fetch <= 0;
        valid_wb <= 0;
    end else if (!stall) begin
        // Propagate the valid signal to future stages.
        valid_fetch <= 1;
    end else if (stall)
        valid_fetch <= 0;

    // Propogate the signals correctly.
    valid_decode <= valid_fetch;
    valid_execute <= valid_decode;
    valid_memory <= valid_execute;
    valid_wb <= valid_memory;
end

    // Adds the messages, with stall and flush checks.
    always @(negedge clk) begin
        if (!rst) begin
            if (valid_fetch) begin
                pipeline_msgs[fetch_id].fetch_msg = fetch_msg;
            end
            if (valid_decode) begin
                pipeline_msgs[decode_id].decode_msg[0] = decode_msg;
                pipeline_msgs[decode_id].decode_msg[1] = instruction_full_msg;
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


    // // Print the message for each instruction.
    // always @(posedge clk) begin
    //     if (valid_wb) begin
    //         $display("==========================================================");
    //         $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline_msgs[wb_id].decode_msg[1], $time / 10);
    //         $display("==========================================================");
    //         // for (int i = 0; i < fetch_msg_id[wb_id]; i = i+1)
    //             $display("%s", pipeline_msgs[wb_id].fetch_msg);
    //         // for (int i = 0; i < decode_msg_id[wb_id]; i = i+1)
    //             $display("%s", pipeline_msgs[wb_id].decode_msg[0]);
    //         $display("%s", pipeline_msgs[wb_id].execute_msg);
    //         $display("%s", pipeline_msgs[wb_id].memory_msg);
    //         $display("%s", pipeline_msgs[wb_id].wb_msg);
    //         $display("==========================================================\n");
    //     end
    // end

endmodule
