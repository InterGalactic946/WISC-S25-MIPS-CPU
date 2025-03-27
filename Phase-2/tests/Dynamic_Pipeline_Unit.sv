module Dynamic_Pipeline_Unit (
    input logic clk, rst,
    input string fetch_msg,
    input string decode_msg,
    input string instruction_full_msg,
    input string execute_msg,
    input string memory_msg,
    input string wb_msg,
    input logic stall
);
    parameter int MAX_INSTR = 5;  // Max instructions in pipeline

    // Define pipeline stages
    typedef enum {FETCH, DECODE, EXECUTE, MEMORY, WRITEBACK, EMPTY} stage_t;

    // Define struct for instruction tracking
    typedef struct {
        stage_t stage;
        string fetch_msgs[0:4], decode_msgs[0:4], instr_full_msg, execute_msg, memory_msg, wb_msg;
        bit print;
    } instr_t;

    // Pipeline: 1D array to track each instruction's stage
    instr_t pipeline[MAX_INSTR];
    int num_instr_in_pipeline, msg_index;  // Number of instructions in the pipeline

    // Simulate pipeline execution
    always_ff @(posedge clk) begin
        if (rst)
            num_instr_in_pipeline <= 1;
        else if (num_instr_in_pipeline < MAX_INSTR && !stall)
            num_instr_in_pipeline <= num_instr_in_pipeline + 1;
    end

    // Simulate pipeline execution
    always_ff @(posedge clk) begin
        if (rst || !stall)
            msg_index <= 0;
        else if (stall)
            msg_index <= msg_index + 1;
    end
        

    // Simulate pipeline execution
    always_ff @(negedge clk) begin
        if (rst) begin
            for (int i = 0; i < MAX_INSTR; i++) begin
                if (i === 0)
                    pipeline[i] <= '{FETCH, '{default: ""}, '{default: ""}, "", "", "", "", 0};
                else
                    pipeline[i] <= '{EMPTY, '{default: ""}, '{default: ""}, "", "", "", "", 0};
            end
        end else begin
            // Handle stall during DECODE stage
            for (int i = 0; i < num_instr_in_pipeline; i++) begin
                case (pipeline[i].stage)
                    FETCH:    pipeline[i].fetch_msgs[msg_index] = fetch_msg;
                    DECODE:   begin
                        pipeline[i].decode_msgs[msg_index] = decode_msg;
                        pipeline[i].instr_full_msg = instruction_full_msg;
                    end
                    EXECUTE:  pipeline[i].execute_msg = execute_msg;
                    MEMORY:   pipeline[i].memory_msg = memory_msg;
                    WRITEBACK: pipeline[i].wb_msg = wb_msg;
                endcase
            end

            // Update stages for each instruction.
            for (int i = 0; i < num_instr_in_pipeline; i++) begin
                case (pipeline[i].stage)
                    EMPTY: begin
                        if (!stall)
                            pipeline[i].stage = FETCH;
                        else
                            pipeline[i].stage = EMPTY;
                    end
                    FETCH: begin
                        if (!stall)
                            pipeline[i].stage = DECODE;
                        else
                            pipeline[i].stage = FETCH;
                    end
                    DECODE: begin
                        if (!stall)
                            pipeline[i].stage = DECODE;
                        else
                            pipeline[i].stage = EXECUTE;
                    end
                    EXECUTE:   pipeline[i].stage = MEMORY;
                    MEMORY:    pipeline[i].stage = WRITEBACK;
                    WRITEBACK: begin
                        pipeline[i].print <= 1;
                        pipeline[i].stage = EMPTY;
                    end
                endcase
            end

            for (int i = MAX_INSTR-1; i > 0; i=i-1) begin
                if (pipeline[i].print)
                    pipeline[i].print <= 0;
            end

            // Shift pipeline stages only if instruction 0 has reached WRITEBACK
            if (pipeline[0].stage === WRITEBACK) begin
                // Shift pipeline stages and move instructions up
                for (int i = MAX_INSTR-1; i > 0; i=i-1) begin
                    pipeline[i] = pipeline[i-1];  // Shift instructions
                end

                // Handle stage transition for the first instruction to FETCH
                pipeline[0] = '{FETCH, '{default: ""}, '{default: ""}, "", "", "", "", 0};
            end
        end
    end

    // Simulate pipeline execution
    always_ff @(posedge clk) begin
        // Print the pipeline status for each cycle and capture messages
        for (int i = 0; i < num_instr_in_pipeline; i++) begin
            if (pipeline[i].print) begin
                $display("==========================================================");
                $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline[i].instr_full_msg, $time / 10);
                $display("==========================================================");
                
                for (int j = 0; j < 5; j = j+1)
                    if (pipeline[i].fetch_msgs[j] !== "")
                        $display("%s", pipeline[i].fetch_msgs[j]);
               
                for (int j = 0; j < 5; j = j+1)
                    if (pipeline[i].decode_msgs[j] !== "")
                        $display("%s", pipeline[i].decode_msgs[j]);

                $display("%s", pipeline[i].execute_msg);
                $display("%s", pipeline[i].memory_msg);
                $display("%s", pipeline[i].wb_msg);
                $display("==========================================================\n");

                // Reset print flag after displaying
                pipeline[i].print = 0;
            end
        end
    end
endmodule
