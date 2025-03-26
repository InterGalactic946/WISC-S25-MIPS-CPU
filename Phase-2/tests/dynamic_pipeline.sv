module dynamic_pipeline (
    input logic clk,
    input logic rst,
    input logic PC_stall,        // Stall Fetch stage
    input logic IF_ID_stall,     // Stall Decode stage
    input logic IF_flush,
    input string fetch_msg,
    input string decode_msg,
    input string instruction_full_msg,
    input string execute_msg,
    input string memory_msg,
    input string wb_msg
);

parameter NUM_PIPELINE = 5;

typedef enum {EMPTY, FETCH, DECODE, EXECUTE, MEMORY, WRITE_BACK} stage_t;

typedef struct {
    string fetch_msgs[0:4];
    string decode_msgs[0:4];
    string instr_full_msg;
    string execute_msg;
    string memory_msg;
    string wb_msg;
    stage_t stage;
} instr_msg_t;

instr_msg_t pipeline[NUM_PIPELINE];
logic [31:0] cycle_count;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cycle_count <= 0;
    end else begin
        cycle_count <= cycle_count + 1;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (int i = 0; i < NUM_PIPELINE; i++) begin
            pipeline[i].stage <= EMPTY;
        end
    end else begin
        for (int i = NUM_PIPELINE-1; i >= 0; i--) begin
            if (pipeline[i].stage == EMPTY && i == 0 && valid_fetch) begin
                pipeline[i].stage <= FETCH;
            end
            else if (pipeline[i].stage == FETCH && !PC_stall) begin
                pipeline[i].stage <= DECODE;
            end
            else if (pipeline[i].stage == DECODE && !IF_ID_stall) begin
                pipeline[i].stage <= EXECUTE;
            end
            else if (pipeline[i].stage == EXECUTE) begin
                pipeline[i].stage <= MEMORY;
            end
            else if (pipeline[i].stage == MEMORY) begin
                pipeline[i].stage <= WRITE_BACK;
            end
        end
    end
end

assign valid_fetch = (pipeline[0].stage == EMPTY) && !PC_stall && !IF_ID_stall;

always @(negedge clk or posedge rst) begin
    if (rst) begin
        for (int i = 0; i < NUM_PIPELINE; i++) begin
            pipeline[i].fetch_msgs = '{default: ""};
            pipeline[i].decode_msgs = '{default: ""};
            pipeline[i].instr_full_msg = "";
            pipeline[i].execute_msg = "";
            pipeline[i].memory_msg = "";
            pipeline[i].wb_msg = "";
        end
    end else begin
        for (int i = 0; i < NUM_PIPELINE; i++) begin
            case (pipeline[i].stage)
                FETCH: begin
                    pipeline[i].fetch_msgs[$countones(pipeline[i].fetch_msgs)] = {fetch_msg, " @ Cycle: ", $sformatf("%0d", cycle_count)};
                end
                DECODE: begin
                    pipeline[i].decode_msgs[$countones(pipeline[i].decode_msgs)] = {decode_msg, " @ Cycle: ", $sformatf("%0d", cycle_count)};
                    pipeline[i].instr_full_msg = (IF_ID_stall) ? ((IF_flush) ? "FLUSHED" : "") : instruction_full_msg;
                end
                EXECUTE: pipeline[i].execute_msg = execute_msg;
                MEMORY: pipeline[i].memory_msg = memory_msg;
                WRITE_BACK: pipeline[i].wb_msg = wb_msg;
            endcase
        end
    end
end

always @(posedge clk) begin
    for (int i = 0; i < NUM_PIPELINE; i++) begin
        if (pipeline[i].stage === WRITE_BACK) begin
            $display("==========================================================");
            if (pipeline[i].instr_full_msg !== "")
                $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline[i].instr_full_msg, cycle_count);
            $display("==========================================================");
            
            for (int j = 0; j < 5; j++) begin
                if (pipeline[i].fetch_msgs[j] !== "")
                    $display("|%s", pipeline[i].fetch_msgs[j]);
            end
            
            for (int j = 0; j < 5; j++) begin
                if (pipeline[i].decode_msgs[j] !== "")
                    $display("|%s", pipeline[i].decode_msgs[j]);
            end

            $display("|%s", pipeline[i].execute_msg);
            $display("|%s", pipeline[i].memory_msg);
            $display("|%s", pipeline[i].wb_msg);
            $display("==========================================================");
            
            pipeline[i].stage <= EMPTY;
        end
    end
end

endmodule
