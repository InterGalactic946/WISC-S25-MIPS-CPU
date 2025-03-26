module Dynamic_Pipeline_Unit (
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

logic valid_fetch, print;

typedef enum {EMPTY, FETCH, DECODE, EXECUTE, MEMORY, WRITE_BACK} stage_t;

typedef struct {
    string fetch_msgs[0:4];  // Array to store fetch stage messages (up to 5 cycles)
    string decode_msgs[0:4]; // Array to store decode stage messages (up to 5 cycles)
    string execute_msg;      // Single message for execute stage
    string memory_msg;       // Single message for memory stage
    string wb_msg;           // Single message for write-back stage
    stage_t stage;           // Current stage of the instruction
} instr_msg_t;

instr_msg_t pipeline[NUM_PIPELINE];  // Pipeline array for storing each instruction's messages

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
            pipeline[i].stage = EMPTY;
            pipeline[i].fetch_msgs = '{default: ""};  // Initialize all fetch messages to empty
            pipeline[i].decode_msgs = '{default: ""}; // Initialize all decode messages to empty
            pipeline[i].execute_msg = "";
            pipeline[i].memory_msg = "";
            pipeline[i].wb_msg = "";
        end
    end else begin
        for (int i = 0; i < NUM_PIPELINE; i++) begin
            case (pipeline[i].stage)
                EMPTY: begin
                    if (valid_fetch) begin
                        pipeline[i].stage = FETCH;
                    end
                end
                FETCH: begin
                    if (!PC_stall) begin
                        pipeline[i].stage = DECODE;
                    end
                end
                DECODE: begin
                    if (!IF_ID_stall) begin
                        pipeline[i].stage = EXECUTE;
                    end
                end
                EXECUTE: pipeline[i].stage = MEMORY;
                MEMORY: pipeline[i].stage = WRITE_BACK;
            endcase
        end
    end
end

assign valid_fetch = (!PC_stall);

always @(negedge clk or posedge rst) begin
    if (rst) begin
        for (int i = 0; i < NUM_PIPELINE; i++) begin
            // Reset all messages
            pipeline[i].fetch_msgs = '{default: ""};
            pipeline[i].decode_msgs = '{default: ""};
            pipeline[i].execute_msg = "";
            pipeline[i].memory_msg = "";
            pipeline[i].wb_msg = "";
        end
    end else begin
        for (int i = 0; i < NUM_PIPELINE; i++) begin
            case (pipeline[i].stage)
                FETCH: begin
                    if (PC_stall) begin
                        // Append fetch message to the fetch_msgs array if stalled
                        pipeline[i].fetch_msgs[cycle_count % 5] = {fetch_msg, " @ Cycle: ", $sformatf("%0d", cycle_count)};
                    end else begin
                        // If not stalled, store the message at the first slot
                        pipeline[i].fetch_msgs[0] = {fetch_msg, " @ Cycle: ", $sformatf("%0d", cycle_count)};
                    end
                end
                DECODE: begin
                    if (IF_ID_stall) begin
                        // Append decode message to the decode_msgs array if stalled
                        pipeline[i].decode_msgs[cycle_count % 5] = {decode_msg, " @ Cycle: ", $sformatf("%0d", cycle_count)};
                    end else begin
                        // If not stalled, store the message at the first slot
                        pipeline[i].decode_msgs[0] = {decode_msg, " @ Cycle: ", $sformatf("%0d", cycle_count)};
                    end
                end
                EXECUTE: begin
                    pipeline[i].execute_msg = {execute_msg, " @ Cycle: ", $sformatf("%0d", cycle_count)};
                end
                MEMORY: begin
                    pipeline[i].memory_msg = {memory_msg, " @ Cycle: ", $sformatf("%0d", cycle_count)};
                end
                WRITE_BACK: begin
                    pipeline[i].wb_msg = {wb_msg, " @ Cycle: ", $sformatf("%0d", cycle_count)};
                end
            endcase
        end
    end
end

// Print all the messages when instruction reaches WRITE_BACK stage
always @(posedge clk) begin
    if (print) begin
        for (int i = 0; i < NUM_PIPELINE; i++) begin
            if (pipeline[i].stage === WRITE_BACK) begin
                $display("==========================================================");
                $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline[i].wb_msg, cycle_count);
                $display("==========================================================");
                
                // Print all messages for the instruction from FETCH stage (if any)
                for (int j = 0; j < 5; j++) begin
                    if (pipeline[i].fetch_msgs[j] !== "") begin
                        $display("| %s", pipeline[i].fetch_msgs[j]);
                    end
                end

                // Print all messages for the instruction from DECODE stage (if any)
                for (int j = 0; j < 5; j++) begin
                    if (pipeline[i].decode_msgs[j] !== "") begin
                        $display("| %s", pipeline[i].decode_msgs[j]);
                    end
                end

                // Print EXECUTE, MEMORY, and WRITE_BACK stage messages
                $display("| %s", pipeline[i].execute_msg);
                $display("| %s", pipeline[i].memory_msg);
                $display("| %s", pipeline[i].wb_msg);

                $display("==========================================================\n");
                
                // Reset the instruction's stage to EMPTY after printing
                pipeline[i].stage <= EMPTY;
            end
        end
    end
end

// Enable print flag once an instruction reaches WRITE_BACK
always @(posedge clk) begin
    if (rst) begin
        print <= 0;
    end else begin
        for (int i = 0; i < NUM_PIPELINE; i++) begin
            if (pipeline[i].stage === WRITE_BACK) begin
                print <= 1;
                break;
            end else begin
                print <= 0;
            end
        end
    end
end

endmodule
