// A hypothetical structure for holding the instruction state
reg [31:0] pipeline_msgs [0:5];  // Assuming 6 stages (Fetch, Decode, Execute, etc.)

// Cycle counters for each stage
integer cycle_fetch, cycle_decode, cycle_execute, cycle_memory, cycle_wb;

always @(posedge clk) begin
    if (rst) begin
        // Reset all stages on reset
        cycle_fetch <= 0;
        cycle_decode <= 0;
        cycle_execute <= 0;
        cycle_memory <= 0;
        cycle_wb <= 0;
    end else begin
        // Increment cycles for each stage
        if (valid_fetch) cycle_fetch <= cycle_fetch + 1;
        if (valid_decode) cycle_decode <= cycle_decode + 1;
        if (valid_execute) cycle_execute <= cycle_execute + 1;
        if (valid_memory) cycle_memory <= cycle_memory + 1;
        if (valid_wb) cycle_wb <= cycle_wb + 1;
    end
end

// Display messages for each instruction
always @(posedge clk) begin
    if (valid_wb) begin
        // Print instruction header
        $display("==========================================================");
        $display("| Instruction: %s | Completed At Cycle: %0t |", instruction_name, cycle_wb);
        $display("==========================================================");

        // FETCH Stage Message
        $display("|[FETCH] %s: PC_curr: 0x%h, PC_next: 0x%h, Instruction: 0x%h", fetch_msg_status, PC_curr, PC_next, instruction);
        $display("| Branch Predicted %s. @ Cycle: %0t", branch_predicted ? "TAKEN" : "NOT Taken", cycle_fetch);

        // DECODE Stage Message
        if (decode_stalled) begin
            $display("|[DECODE] STALL: Instruction stalled at decode due to Branch hazard. @ Cycle: %0t", cycle_decode);
        end else begin
            $display("|[DECODE] SUCCESS: Opcode = 0b%0b, Instr: %s, rs = 0x%h, rt = 0x%h, rd = 0x%h. @ Cycle: %0t", opcode, instruction_name, rs, rt, rd, cycle_decode);
        end

        // EXECUTE Stage Message
        $display("|[EXECUTE] SUCCESS: Input_A = 0x%h, Input_B = 0x%h, ALU_out = 0x%h, Z_set = %b, V_set = %b, N_set = %b. @ Cycle: %0t", 
                 input_A, input_B, ALU_out, Z_set, V_set, N_set, cycle_execute);

        // MEMORY Stage Message
        if (memory_access) begin
            $display("|[MEMORY] SUCCESS: Memory access performed. @ Cycle: %0t", cycle_memory);
        end else begin
            $display("|[MEMORY] SUCCESS: No memory access in this cycle. @ Cycle: %0t", cycle_memory);
        end

        // WRITE-BACK Stage Message
        if (register_write) begin
            $display("|[WRITE-BACK] SUCCESS: Register %0d written with data: 0x%h. @ Cycle: %0t", write_register, write_data, cycle_wb);
        end else begin
            $display("|[WRITE-BACK] SUCCESS: No register write in this cycle. @ Cycle: %0t", cycle_wb);
        end
        $display("==========================================================\n");
    end
end
