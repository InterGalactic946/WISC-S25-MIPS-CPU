module CPU (
    input logic clk,              // Clock
    input logic rst,              // Reset
    input logic stall,            // Stall signal
    input logic flush,            // Flush signal
    input logic [15:0] PC_curr,   // Current PC
    input logic [15:0] PC_next,   // Next PC
    input logic [15:0] PC_inst,   // Instruction
    input logic [1:0] prediction, // Branch prediction
    input logic [15:0] predicted_target, // Predicted target
    input logic [15:0] expected_PC_curr, // Expected PC (from model)
    input logic [15:0] expected_PC_next, // Expected next PC (from model)
    input logic [15:0] expected_PC_inst, // Expected instruction (from model)
    input logic [1:0] expected_prediction, // Expected prediction (from model)
    input logic [15:0] expected_predicted_target, // Expected predicted target (from model)
    output logic [3:0] IF_ID_PC_curr,
    output logic [15:0] IF_ID_PC_next,
    output logic [15:0] IF_ID_PC_inst,
    output logic [1:0] IF_ID_prediction,
    output logic [15:0] IF_ID_predicted_target
);

    // Pipeline stage indices for different instructions
    integer fetch_id;
    integer decode_id;
    integer execute_id;
    integer memory_id;
    integer wb_id;

    typedef struct {
        string fetch_msg;
        integer fetch_cycle;

        string if_id_msg;   // IF/ID Register message
        integer if_id_cycle;

        string decode_msg[0:1];
        integer decode_cycle;

        string id_ex_msg;   // ID/EX Register message
        integer id_ex_cycle;

        string execute_msg;
        integer execute_cycle;

        string ex_mem_msg;  // EX/MEM Register message
        integer ex_mem_cycle;

        string memory_msg;
        integer memory_cycle;

        string mem_wb_msg;  // MEM/WB Register message
        integer mem_wb_cycle;

        string wb_msg;
        integer wb_cycle;
    } debug_info_t;

    // Declare an array to store debug messages for each instruction
    debug_info_t pipeline_msgs[0:35];

    // Keep track of all instructions in the pipeline.
    always @(posedge clk) begin
        if (rst) begin
            // Reset the pipeline indices.
            fetch_id  <= 0;
            decode_id <= -1;
            execute_id <= -2;
            memory_id  <= -3;
            wb_id <= -4;
        end else begin
            // Fetch Stage
            if (fetch_id >= 0) begin
                pipeline_msgs[fetch_id].fetch_msg <= verify_FETCH(fetch_id);
                pipeline_msgs[fetch_id].fetch_cycle <= $time / 10;
            end

            // Decode Stage (IF/ID pipeline register & decode)
            if (decode_id >= 0) begin
                pipeline_msgs[decode_id].if_id_msg   <= verify_IF_ID(decode_id);
                pipeline_msgs[decode_id].if_id_cycle <= $time / 10;

                pipeline_msgs[decode_id].decode_msg[0] <= verify_DECODE(decode_id);
                pipeline_msgs[decode_id].decode_msg[1] <= verify_DECODE(decode_id);
                pipeline_msgs[decode_id].decode_cycle  <= $time / 10;
            end

            // Execute Stage (ID/EX pipeline register & execute)
            if (execute_id >= 0) begin
                pipeline_msgs[execute_id].id_ex_msg   <= verify_ID_EX(execute_id);
                pipeline_msgs[execute_id].id_ex_cycle <= $time / 10;

                pipeline_msgs[execute_id].execute_msg   <= verify_EXECUTE(execute_id);
                pipeline_msgs[execute_id].execute_cycle <= $time / 10;
            end

            // Memory Stage (EX/MEM pipeline register & memory)
            if (memory_id >= 0) begin
                pipeline_msgs[memory_id].ex_mem_msg   <= verify_EX_MEM(memory_id);
                pipeline_msgs[memory_id].ex_mem_cycle <= $time / 10;

                pipeline_msgs[memory_id].memory_msg   <= verify_MEMORY(memory_id);
                pipeline_msgs[memory_id].memory_cycle <= $time / 10;
            end

            // Write-Back Stage (MEM/WB pipeline register & write-back)
            if (wb_id >= 0) begin
                pipeline_msgs[wb_id].mem_wb_msg   <= verify_MEM_WB(wb_id);
                pipeline_msgs[wb_id].mem_wb_cycle <= $time / 10;

                pipeline_msgs[wb_id].wb_msg   <= verify_WRITEBACK(wb_id);
                pipeline_msgs[wb_id].wb_cycle <= $time / 10;

                // Print all messages for this instruction when it reaches WB.
                $display("=====================================================");
                $display("| Instruction: %s | Clock Cycle: %0t |", pipeline_msgs[wb_id].decode_msg[1], $time/10);
                $display("=====================================================");
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].fetch_msg, pipeline_msgs[wb_id].fetch_cycle);
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].if_id_msg, pipeline_msgs[wb_id].if_id_cycle);
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].decode_msg[0], pipeline_msgs[wb_id].decode_cycle);
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].id_ex_msg, pipeline_msgs[wb_id].id_ex_cycle);
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].execute_msg, pipeline_msgs[wb_id].execute_cycle);
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].ex_mem_msg, pipeline_msgs[wb_id].ex_mem_cycle);
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].memory_msg, pipeline_msgs[wb_id].memory_cycle);
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].mem_wb_msg, pipeline_msgs[wb_id].mem_wb_cycle);
                $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].wb_msg, pipeline_msgs[wb_id].wb_cycle);
                $display("=====================================================");
            end
            
            // Move all stage indices forward if not stalling or flushing.
            if (!stall || !flush) begin
                fetch_id  <= fetch_id + 1;
                decode_id <= decode_id + 1;
                execute_id <= execute_id + 1;
                memory_id  <= memory_id + 1;
                wb_id <= wb_id + 1;
            end
        end
    end
module cpu_pipeline;

module VerificationModule (
    input logic clk // Clock input
);

    // Declare signals for testing (example inputs and outputs)
    logic [15:0] PC_next, expected_PC_next, PC_inst, expected_PC_inst, PC_curr, expected_PC_curr;
    logic [1:0] prediction, expected_prediction;
    logic [15:0] predicted_target, expected_predicted_target;
    string stage_msg;

    logic [65:0] IF_ID_signals, expected_IF_ID_signals;
    string if_id_msg;

    logic [62:0] EX_signals, expected_EX_signals;
    logic [17:0] MEM_signals, expected_MEM_signals;
    logic [7:0] WB_signals, expected_WB_signals;
    logic [2:0] cc, flag_reg;
    logic is_branch, expected_is_branch;
    logic is_BR, expected_is_BR;
    logic [15:0] branch_target, expected_branch_target;
    logic actual_taken, expected_actual_taken;
    logic wen_BTB, expected_wen_BTB;
    logic wen_BHT, expected_wen_BHT;
    logic update_PC, expected_update_PC;
    string decode_msg, instruction_full;

    


endmodule




endmodule
