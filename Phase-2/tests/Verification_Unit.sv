// Define structure for debug info with dynamic arrays
typedef struct {
    string fetch_msgs[$];
    int    fetch_cycle;
    string decode_msgs[$];
    int    decode_cycle;
    string exec_msgs[$];
    int    exec_cycle;
    string mem_msgs[$];
    int    mem_cycle;
    string wb_msgs[$];
    int    wb_cycle;
} debug_info_t;

debug_info_t pipeline_msgs[MAX_INSTRUCTIONS];

// Main logic for processing fetch and decode stages
always @(posedge clk) begin
    if (fetch_msg != "") begin
        // Fetch stage
        if (pipeline_msgs[instr_index].fetch_msgs.size() == 0 || 
            fetch_msg != pipeline_msgs[instr_index].fetch_msgs[$] ) begin
            pipeline_msgs[instr_index].fetch_msgs.push_back(fetch_msg);
            pipeline_msgs[instr_index].fetch_cycle = $time / 10;
        end
    end
    
    if (decode_msg != "") begin
        // Decode stage
        if (pipeline_msgs[instr_index].decode_msgs.size() == 0 || 
            decode_msg != pipeline_msgs[instr_index].decode_msgs[$] ) begin
            pipeline_msgs[instr_index].decode_msgs.push_back(decode_msg);
            pipeline_msgs[instr_index].decode_cycle = $time / 10;
        end
    end
end

// Handle Flushed Instructions
always @(posedge clk) begin
    if (flush_condition) begin
        // When flush occurs, capture the flush message once
        pipeline_msgs[instr_index].fetch_msgs.push_back("FLUSHED due to misprediction.");
        pipeline_msgs[instr_index].decode_msgs.push_back("FLUSHED due to misprediction.");
        pipeline_msgs[instr_index].exec_msgs.push_back("FLUSHED.");
        pipeline_msgs[instr_index].mem_msgs.push_back("No memory access.");
        pipeline_msgs[instr_index].wb_msgs.push_back("No register write.");
        pipeline_msgs[instr_index].fetch_cycle = $time / 10;
    end
end

// Printing logic at the end of the instruction completion cycle
always @(negedge clk) begin
    if (instruction_completed) begin
        // Print each stage's message at the end of the instruction
        $display("===========================================================");
        $display("| Instruction: %s | Completed At Cycle: %0d |", pipeline_msgs[instr_index].instruction, pipeline_msgs[instr_index].wb_cycle);
        $display("===========================================================");
        
        // Print fetch messages
        foreach (pipeline_msgs[instr_index].fetch_msgs[i]) begin
            $display("|[FETCH] %s @ Cycle: %0d", pipeline_msgs[instr_index].fetch_msgs[i], pipeline_msgs[instr_index].fetch_cycle);
        end
        
        // Print decode messages
        foreach (pipeline_msgs[instr_index].decode_msgs[i]) begin
            $display("|[DECODE] %s @ Cycle: %0d", pipeline_msgs[instr_index].decode_msgs[i], pipeline_msgs[instr_index].decode_cycle);
        end
        
        // Print other stages (execute, memory, write-back)
        foreach (pipeline_msgs[instr_index].exec_msgs[i]) begin
            $display("|[EXECUTE] %s @ Cycle: %0d", pipeline_msgs[instr_index].exec_msgs[i], pipeline_msgs[instr_index].exec_cycle);
        end
        
        foreach (pipeline_msgs[instr_index].mem_msgs[i]) begin
            $display("|[MEMORY] %s @ Cycle: %0d", pipeline_msgs[instr_index].mem_msgs[i], pipeline_msgs[instr_index].mem_cycle);
        end
        
        foreach (pipeline_msgs[instr_index].wb_msgs[i]) begin
            $display("|[WRITE-BACK] %s @ Cycle: %0d", pipeline_msgs[instr_index].wb_msgs[i], pipeline_msgs[instr_index].wb_cycle);
        end
        
        $display("===========================================================");
    end
end
