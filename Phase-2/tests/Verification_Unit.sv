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
    input logic PC_stall, IF_ID_stall
    );

    integer fetch_id, decode_id, execute_id, memory_id, wb_id, msg_index, max_index;
    integer fetch_msg_id[0:71], decode_msg_id[0:71];
    logic valid_fetch, valid_decode, print, valid_execute, stall, valid_memory, valid_wb, print_enable;
    debug_info_t pipeline_msgs[0:71];

// First Always Block: Tracks the pipeline and increments IDs
// First Always Block: Tracks the pipeline and increments IDs
always @(posedge clk) begin
    if (rst) begin
        // Initialize pipeline registers on reset
        fetch_id   <= 0;
        decode_id  <= -1;
        execute_id <= -2;
        memory_id  <= -3;
        wb_id      <= -4;
    end else if (PC_stall && IF_ID_stall) begin
        // Both fetch and decode are stalled (hold current values)
        fetch_id <= fetch_id;           // Stall the instruction in fetch
        decode_id <= decode_id;         // Stall the instruction in decode
        execute_id <= decode_id;        // Pass the decode_id to execute_id
        memory_id  <= execute_id;       // Pass the execute_id to memory_id
        wb_id      <= memory_id;        // Pass the memory_id to wb_id
    end else if (!PC_stall && !IF_ID_stall) begin
        // No stalls, pipeline moves forward
        fetch_id <= fetch_id + 1;       // Fetch the next instruction
        decode_id <= fetch_id;          // Pass the fetch_id to decode_id
        execute_id <= decode_id;        // Pass the decode_id to execute_id
        memory_id  <= execute_id;       // Pass the execute_id to memory_id
        wb_id      <= memory_id;        // Pass the memory_id to wb_id
    end    
end

// // Second Always Block: Propagate the valid signals across stages
// always @(posedge clk) begin
//     if (rst) begin
//         valid_decode <= 0;
//         valid_execute <= 0;
//         valid_memory <= 0;
//         valid_fetch <= 1;
//         valid_wb <= 0;
//     end else if (!stall) begin
//         // Propagate the valid signal to future stages.
//         valid_fetch <= 1;
//     end else if (stall) begin
//         valid_fetch <= 0;
//     end

//     // Propogate the signals correctly.
//     valid_decode <= valid_fetch;
//     valid_execute <= valid_decode;
//     valid_memory <= valid_execute;
//     valid_wb <= valid_memory;
// end

 // We stall on PC or IF.
  assign stall = PC_stall || IF_ID_stall;

  // We flush IF, or ID stage.
//   assign flush = iDUT.IF_flush || iDUT.ID_flush;

always @(posedge clk) begin
  if (rst || !stall) begin
    msg_index <= 0;
  end else if (stall)
    msg_index <= msg_index + 1;
end

// Adds the messages, with stall and flush checks.
always @(negedge clk) begin
    if (rst) begin
        pipeline_msgs[fetch_id].fetch_msgs = '{default: ""};
    end else if (fetch_id >= 0) begin
        pipeline_msgs[fetch_id].fetch_msgs[msg_index] = fetch_msg;
    end
end


// Adds the messages, with stall and flush checks.
always @(negedge clk) begin
    if (rst) begin
        pipeline_msgs[decode_id].decode_msgs = '{default: '{ "", "" }};
    end else if (decode_id >= 0) begin
        pipeline_msgs[decode_id].decode_msgs[msg_index][0] = decode_msg;
        pipeline_msgs[decode_id].decode_msgs[msg_index][1] = instruction_full_msg;
    end
end

// Adds the messages, with stall and flush checks.
always @(negedge clk) begin
    if (rst) begin
        pipeline_msgs[execute_id].execute_msg = "";
    end else if (execute_id >= 0) begin
        pipeline_msgs[execute_id].execute_msg = execute_msg;
    end
end


// Adds the messages, with stall and flush checks.
always @(negedge clk) begin
    if (rst) begin
        pipeline_msgs[memory_id].memory_msg = "";
    end else if (memory_id >= 0) begin
        pipeline_msgs[memory_id].memory_msg = mem_msg;
    end
end


// Adds the messages, with stall and flush checks.
always @(negedge clk) begin
    if (rst) begin
        pipeline_msgs[wb_id].wb_msg = "";
    end else if (wb_id >= 0) begin
        pipeline_msgs[wb_id].wb_msg = wb_msg;
    end
end

    always @(posedge clk)
        if (rst)
            print <= 1'b0;
        else if (wb_id >= 0)
            print <= 1'b1;
        else
            print <= 1'b0;
        

    // Print the message for each instruction.
    always @(posedge clk) begin
        if (print) begin
            for (int i = 0; i < 5; i = i + 1) begin
                max_index = 0;
                if (pipeline_msgs[wb_id].decode_msgs[i][1] !== "")
                    max_index = max_index + 1;
            end
            $display("==========================================================");
            $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline_msgs[wb_id].decode_msgs[max_index][1], $time / 10);
            $display("==========================================================");
            for (int i = 0; i < 5; i = i+1)
                if (pipeline_msgs[wb_id].fetch_msgs[i] !== "")
                    $display("%s", pipeline_msgs[wb_id].fetch_msgs[i]);
            // $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].fetch_msgs[i], pipeline_msgs[wb_id].fetch_cycle);            
            for (int i = 0; i < 5; i = i+1)
                if (pipeline_msgs[wb_id].decode_msgs[i][0] !== "")
                    $display("%s", pipeline_msgs[wb_id].decode_msgs[i][0]);
            // $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].decode_msg[0], pipeline_msgs[wb_id].decode_cycle);
            $display("%s", pipeline_msgs[wb_id].execute_msg);
            $display("%s", pipeline_msgs[wb_id].memory_msg);
            $display("%s", pipeline_msgs[wb_id].wb_msg);
            $display("==========================================================\n");
        end
    end

endmodule
