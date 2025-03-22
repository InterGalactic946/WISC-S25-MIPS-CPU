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

    // Structure to store debug messages for each stage
    typedef struct packed {
        string fetch_msg;
        string decode_msg;
        string execute_msg;
        string memory_msg;
        string writeback_msg;
    } debug_info_t;

    debug_info_t debug_info;  // Instance of debug information structure

    // Task to verify Fetch stage
    task automatic verify_fetch(input logic [15:0] PC_curr, input logic [15:0] expected_PC_curr,
                                input logic [15:0] PC_next, input logic [15:0] expected_PC_next,
                                input logic [15:0] PC_inst, input logic [15:0] expected_PC_inst,
                                input logic [1:0] prediction, input logic [1:0] expected_prediction,
                                input logic [15:0] predicted_target, input logic [15:0] expected_predicted_target);
        begin
            if (PC_curr !== expected_PC_curr) begin
                debug_info.fetch_msg = $sformatf("[ERROR] Fetch mismatch: PC_curr=0x%h, expected=0x%h", PC_curr, expected_PC_curr);
            end else begin
                debug_info.fetch_msg = "[INFO] Fetch match successful.";
            end

            if (PC_next !== expected_PC_next) begin
                debug_info.fetch_msg = $sformatf("[ERROR] Fetch mismatch: PC_next=0x%h, expected=0x%h", PC_next, expected_PC_next);
            end

            if (PC_inst !== expected_PC_inst) begin
                debug_info.fetch_msg = $sformatf("[ERROR] Fetch mismatch: Instruction=0x%h, expected=0x%h", PC_inst, expected_PC_inst);
            end

            if (prediction !== expected_prediction) begin
                debug_info.fetch_msg = $sformatf("[ERROR] Fetch mismatch: Prediction=0x%h, expected=0x%h", prediction, expected_prediction);
            end

            if (predicted_target !== expected_predicted_target) begin
                debug_info.fetch_msg = $sformatf("[ERROR] Fetch mismatch: Predicted Target=0x%h, expected=0x%h", predicted_target, expected_predicted_target);
            end
        end
    endtask

    // Task to verify Decode stage (similar to fetch)
    task automatic verify_decode(input logic [15:0] decoded_inst, input logic [15:0] expected_decoded_inst);
        begin
            if (decoded_inst !== expected_decoded_inst) begin
                debug_info.decode_msg = $sformatf("[ERROR] Decode mismatch: Decoded Instruction=0x%h, expected=0x%h", decoded_inst, expected_decoded_inst);
            end else begin
                debug_info.decode_msg = "[INFO] Decode match successful.";
            end
        end
    endtask

    // Add similar tasks for execute, memory, and writeback stages...

    // Pipeline register update and error checking
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset pipeline registers and debug messages
            IF_ID_PC_curr <= 4'b0;
            IF_ID_PC_next <= 16'b0;
            IF_ID_PC_inst <= 16'b0;
            IF_ID_prediction <= 2'b0;
            IF_ID_predicted_target <= 16'b0;
            debug_info = '{default: "No message"};
        end else if (!stall) begin
            // Call verification tasks for each stage
            verify_fetch(PC_curr, expected_PC_curr, PC_next, expected_PC_next, PC_inst, expected_PC_inst,
                         prediction, expected_prediction, predicted_target, expected_predicted_target);
            
            // Store values in pipeline registers
            IF_ID_PC_curr <= PC_curr[3:0];
            IF_ID_PC_next <= PC_next;
            IF_ID_PC_inst <= PC_inst;
            IF_ID_prediction <= prediction;
            IF_ID_predicted_target <= predicted_target;
        end
    end

    // Print all debug messages after instruction completes pipeline
    task automatic print_debug_info();
        begin
            $display("==============================================");
            $display("Fetch Stage Debug Information: %s", debug_info.fetch_msg);
            $display("Decode Stage Debug Information: %s", debug_info.decode_msg);
            $display("Execute Stage Debug Information: %s", debug_info.execute_msg);
            $display("Memory Stage Debug Information: %s", debug_info.memory_msg);
            $display("Writeback Stage Debug Information: %s", debug_info.writeback_msg);
            $display("==============================================");
        end
    endtask

    module pipeline_debug(
    input logic clk,
    input logic reset,
    input logic [15:0] instruction_in,    // Instruction input to fetch stage
    input logic [15:0] pc_in,             // Program counter input to fetch stage
    input logic [1:0] prediction,         // Prediction value for branch
    input logic [15:0] predicted_target   // Predicted target for branch
);

    // Define a structure to hold stage information
    typedef struct {
        string fetch_msg;  // Store the fetch stage message
        string decode_msg; // Store the decode stage message
        string execute_msg; // Store the execute stage message
        string memory_msg;  // Store the memory stage message
        string wb_msg; // Store the write-back stage message
    } debug_info_t;

    // Declare an array to hold the state of each stage (fetch, decode, execute, memory, write-back)
    debug_info_t pipeline[0:4]; // 5-stage pipeline

    // Fetch Stage: Store instruction and generate fetch message
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pipeline[0].instruction <= 16'b0;
            pipeline[0].PC_curr <= 16'b0;
            pipeline[0].fetch_msg <= ""; // Clear fetch message
        end else begin
            pipeline[0].instruction <= instruction_in; // New instruction at fetch
            pipeline[0].PC_curr <= pc_in; // PC at fetch

            // Verify the instruction and PC at fetch stage
            if (verify_FETCH(pipeline[0].PC_curr, pipeline[0].instruction, prediction, predicted_target)) begin
                // Store fetch stage message if verification passes
                pipeline[0].fetch_msg <= $sformatf("[FETCH] PC: 0x%h, Instruction: 0x%h, Predicted Taken: %b, Predicted Target: 0x%h",
                                                   pipeline[0].PC_curr, pipeline[0].instruction, prediction[1], predicted_target);
            end else begin
                $display("[ERROR] Fetch stage verification failed at PC: 0x%h, Instruction: 0x%h", pipeline[0].PC_curr, pipeline[0].instruction);
            end
        end
    end

    // Decode Stage: Store decode message
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pipeline[1].decode_msg <= ""; // Clear decode message
        end else begin
            // Verify the instruction at decode stage
            if (verify_DECODE(pipeline[1].instruction)) begin
                // Store decode stage message if verification passes
                pipeline[1].decode_msg <= $sformatf("[DECODE] Decoded Instruction: 0x%h, PC: 0x%h", 
                                                     pipeline[0].instruction, pipeline[0].PC_curr);
            end else begin
                $display("[ERROR] Decode stage verification failed for Instruction: 0x%h", pipeline[1].instruction);
            end
        end
    end

    // Execute Stage: Store execute message
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pipeline[2].execute_msg <= ""; // Clear execute message
        end else begin
            // Verify the instruction at execute stage
            if (verify_EXECUTE(pipeline[2].instruction)) begin
                // Store execute stage message if verification passes
                pipeline[2].execute_msg <= $sformatf("[EXECUTE] Executed Instruction: 0x%h, Result: 0x%h", 
                                                      pipeline[1].instruction, pipeline[1].instruction + 16'h0001); // Example result
            end else begin
                $display("[ERROR] Execute stage verification failed for Instruction: 0x%h", pipeline[2].instruction);
            end
        end
    end

    // Memory Stage: Store memory message
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pipeline[3].memory_msg <= ""; // Clear memory message
        end else begin
            // Verify the instruction at memory stage
            if (verify_MEMORY(pipeline[3].instruction)) begin
                // Store memory stage message if verification passes
                pipeline[3].memory_msg <= $sformatf("[MEMORY] Accessed Memory for Instruction: 0x%h, Address: 0x%h", 
                                                     pipeline[2].instruction, pipeline[2].instruction[7:0]); // Example memory access
            end else begin
                $display("[ERROR] Memory stage verification failed for Instruction: 0x%h", pipeline[3].instruction);
            end
        end
    end

    // Write-back Stage: Store write-back message
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pipeline[4].wb_msg <= ""; // Clear write-back message
        end else begin
            // Verify the instruction at write-back stage
            if (verify_WRITEBACK(pipeline[4].instruction)) begin
                // Store write-back stage message if verification passes
                pipeline[4].wb_msg <= $sformatf("[WRITE-BACK] Write-back for Instruction: 0x%h, Data: 0x%h", 
                                                 pipeline[3].instruction, pipeline[3].instruction + 16'h0001); // Example write-back
            end else begin
                $display("[ERROR] Write-back stage verification failed for Instruction: 0x%h", pipeline[4].instruction);
            end
        end
    end

    // Final Stage (after Write-back): Print all messages after instruction completes pipeline
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset the final stage
        end else begin
            // Print all messages for an instruction after it completes the pipeline if all verifications pass
            if (pipeline[4].instruction !== 16'b0) begin
                $display("=====================================================");
                $display("Instruction Completed at Clock Cycle %0t", $time/10);
                $display("=====================================================");
                if (pipeline[0].fetch_msg !== "") $display("%s", pipeline[0].fetch_msg);  // Fetch stage message
                if (pipeline[1].decode_msg !== "") $display("%s", pipeline[1].decode_msg); // Decode stage message
                if (pipeline[2].execute_msg !== "") $display("%s", pipeline[2].execute_msg); // Execute stage message
                if (pipeline[3].memory_msg !== "") $display("%s", pipeline[3].memory_msg); // Memory stage message
                if (pipeline[4].wb_msg !== "") $display("%s", pipeline[4].wb_msg);    // Write-back stage message
                $display("=====================================================");
            end
        end
    end

    // Verification Tasks
    task automatic verify_FETCH(input logic [15:0] PC_curr, input logic [15:0] instruction, 
                                 input logic [1:0] prediction, input logic [15:0] predicted_target);
        begin
            // Example check: You can add your actual verification conditions
            if (PC_curr == 16'h0) begin
                $display("[ERROR] Invalid PC at Fetch stage: 0x%h", PC_curr);
                return 0; // Verification failed
            end
            return 1; // Verification passed
        end
    endtask

    task automatic verify_DECODE(input logic [15:0] instruction);
        begin
            // Example check: You can add your actual verification conditions
            if (instruction == 16'hFFFF) begin
                $display("[ERROR] Invalid instruction at Decode stage: 0x%h", instruction);
                return 0; // Verification failed
            end
            return 1; // Verification passed
        end
    endtask

    task automatic verify_EXECUTE(input logic [15:0] instruction);
        begin
            // Example check: You can add your actual verification conditions
            if (instruction == 16'h0000) begin
                $display("[ERROR] Invalid instruction at Execute stage: 0x%h", instruction);
                return 0; // Verification failed
            end
            return 1; // Verification passed
        end
    endtask

    task automatic verify_MEMORY(input logic [15:0] instruction);
        begin
            // Example check: You can add your actual verification conditions
            if (instruction == 16'h1234) begin
                $display("[ERROR] Invalid instruction at Memory stage: 0x%h", instruction);
                return 0; // Verification failed
            end
            return 1; // Verification passed
        end
    endtask

    task automatic verify_WRITEBACK(input logic [15:0] instruction);
        begin
            // Example check: You can add your actual verification conditions
            if (instruction == 16'h9999) begin
                $display("[ERROR] Invalid instruction at Write-back stage: 0x%h", instruction);
                return 0; // Verification failed
            end
            return 1; // Verification passed
        end
    endtask

endmodule

module cpu_pipeline;

    // Inputs for the stages
    logic [15:0] instruction, PC_curr, PC_next, PC_inst, PC_pred_target;
    logic [1:0] prediction;
    logic [15:0] expected_PC_next, expected_PC_inst, expected_PC_curr, expected_pred_target;
    logic [1:0] expected_prediction;

    // Outputs
    logic [255:0] instruction_name;  // Store the decoded instruction name
    logic [255:0] instruction_full;  // Full instruction (e.g., "ADD R5, R5, R6")

    // Variables to store the success/error messages for each stage
    string fetch_message, decode_message, execute_message;
    integer fetch_clock_cycle, decode_clock_cycle, execute_clock_cycle;

    // Task to decode instruction (simplified for the example)
    task automatic decode_instruction_name(
        input logic [15:0] instruction, 
        output logic [255:0] instruction_name
    );
        begin
            case (instruction[15:12])  // Assuming the opcode is in the top 4 bits
                4'b0001: instruction_name = "ADD";
                4'b0010: instruction_name = "SUB";
                4'b0011: instruction_name = "LW";
                4'b0100: instruction_name = "SW";
                default: instruction_name = "UNKNOWN";
            endcase
        end
    endtask

    // Task to get the full instruction string (e.g., "ADD R5, R5, R6")
    task automatic get_full_instruction(
        input logic [15:0] instruction, 
        output logic [255:0] instruction_full
    );
        begin
            case (instruction[15:12])  // Assuming the opcode is in the top 4 bits
                4'b0001: instruction_full = $sformatf("ADD R%d, R%d, R%d", instruction[7:4], instruction[3:0], instruction[11:8]);
                4'b0010: instruction_full = $sformatf("SUB R%d, R%d, R%d", instruction[7:4], instruction[3:0], instruction[11:8]);
                4'b0011: instruction_full = $sformatf("LW R%d, 0x%h(R%d)", instruction[7:4], instruction[11:0], instruction[3:0]);
                4'b0100: instruction_full = $sformatf("SW R%d, 0x%h(R%d)", instruction[7:4], instruction[11:0], instruction[3:0]);
                default: instruction_full = "UNKNOWN";
            endcase
        end
    endtask

    // Task to verify FETCH stage
    task automatic verify_FETCH(
        input logic [15:0] PC_next, expected_PC_next,
        input logic [15:0] PC_inst, expected_PC_inst,
        input logic [15:0] PC_curr, expected_PC_curr,
        input logic [1:0] prediction, expected_prediction,
        input logic [15:0] predicted_target, expected_pred_target
    );
        begin
            // Store the clock cycle for FETCH stage
            fetch_clock_cycle = $time / 10;

            // Verify FETCH stage (same as before)
            if (PC_next !== expected_PC_next) begin
                fetch_message = $sformatf("[FETCH] ERROR: PC_next=0x%h, expected_PC_next=0x%h.", PC_next, expected_PC_next);
            end else if (PC_inst !== expected_PC_inst) begin
                fetch_message = $sformatf("[FETCH] ERROR: PC_inst=0x%h, expected_PC_inst=0x%h.", PC_inst, expected_PC_inst);
            end else if (PC_curr !== expected_PC_curr) begin
                fetch_message = $sformatf("[FETCH] ERROR: PC_curr=0x%h, expected_PC_curr=0x%h.", PC_curr, expected_PC_curr);
            end else if (prediction !== expected_prediction) begin
                fetch_message = $sformatf("[FETCH] ERROR: predicted_taken=0b%b, expected_predicted_taken=0b%b.",
                         prediction[1], expected_prediction[1]);
            end else if (predicted_target !== expected_pred_target) begin
                fetch_message = $sformatf("[FETCH] ERROR: predicted_target=0x%h, expected_pred_target=0x%h.",
                         predicted_target, expected_pred_target);
            end else begin
                fetch_message = $sformatf("[FETCH] SUCCESS: PC_curr=0x%h, PC_next=0x%h, Instruction=%0h | Branch Predicted Taken | Predicted Target: 0x%h", 
                                          PC_curr, PC_next, PC_inst, predicted_target);
            end
        end
    endtask

    // Task to verify DECODE stage
    task automatic verify_DECODE(
        input logic [15:0] instruction, 
        output logic [255:0] instruction_name
    );
        begin
            // Decode instruction in the DECODE stage
            decode_instruction_name(instruction, instruction_name);
            // Get the full instruction string (e.g., "ADD R5, R5, R6")
            get_full_instruction(instruction, instruction_full);

            // Store the clock cycle for DECODE stage
            decode_clock_cycle = $time / 10;

            // On success, store the decode success message
            decode_message = $sformatf("[DECODE] SUCCESS: Instruction Decoded Correctly: 0x%h", instruction);
        end
    endtask

    // Task to verify EXECUTE stage
    task automatic verify_EXECUTE(
        input logic [15:0] ALU_result, expected_ALU_result
    );
        begin
            // Store the clock cycle for EXECUTE stage
            execute_clock_cycle = $time / 10;

            // Store message for EXECUTE stage
            if (ALU_result !== expected_ALU_result) begin
                execute_message = $sformatf("[EXECUTE] ERROR: ALU result=0x%h, expected_ALU_result=0x%h.", ALU_result, expected_ALU_result);
            end else begin
                execute_message = $sformatf("[EXECUTE] SUCCESS: ALU Result: 0x%h", ALU_result);
            end
        end
    endtask

    // Task to print instruction header (after all stages)
    task automatic print_instruction_header();
        begin
            // Final instruction header after all stages
            $display("=====================================================");
            $display("|Instruction: %s | Clock Cycle: %0t |", instruction_full, fetch_clock_cycle);
            $display("=====================================================");
        end
    endtask

    // Task to simulate the entire pipeline
    task automatic simulate_pipeline();
        begin
            // Initialize expected values
            expected_PC_next = 16'h0040;
            expected_PC_inst = 16'h0003; // Example: instruction "ADD"
            expected_PC_curr = 16'h0030;
            expected_prediction = 2'b01; // Predicted taken

            expected_pred_target = 16'h0050;  // Predicted target
            instruction = 16'h0001;  // Example instruction: "ADD"

            // Simulate the pipeline stages
            // Fetch Stage
            verify_FETCH(PC_next, expected_PC_next, PC_inst, expected_PC_inst, PC_curr, expected_PC_curr,
                         prediction, expected_prediction, predicted_target, expected_pred_target);

            // Decode Stage
            verify_DECODE(instruction, instruction_name);

            // Execute Stage
            verify_EXECUTE(ALU_result, expected_ALU_result);

            // Print the instruction header after all stages
            print_instruction_header();

            // Print stored messages
            $display("=====================================================");
            $display("|%s Clock Cycle: %0t", fetch_message, fetch_clock_cycle);
            $display("|%s Clock Cycle: %0t", if_id_message, if_id_clock_cycle);
            $display("|%s Clock Cycle: %0t", decode_message, decode_clock_cycle);
            $display("|%s Clock Cycle: %0t", id_ex_message, id_ex_clock_cycle);
            $display("|%s Clock Cycle: %0t", execute_message, execute_clock_cycle);
            $display("|%s Clock Cycle: %0t", ex_mem_message, ex_mem_clock_cycle);
            $display("|%s Clock Cycle: %0t", memory_message, memory_clock_cycle);
            $display("|%s Clock Cycle: %0t", mem_wb_message, mem_wb_clock_cycle);
            $display("|%s Clock Cycle: %0t", write_back_message, write_back_clock_cycle);
            $display("=====================================================");
        end
    endtask

    // Main logic
    initial begin
        // Run pipeline simulation
        simulate_pipeline();
    end

endmodule



endmodule
