module dynamic_pipeline();
    typedef enum { EMPTY, FETCH, DECODE, EXECUTE, MEMORY, WRITE_BACK } stage_t;
    
    parameter int NUM_INSTR = 4;
    parameter int MAX_CYCLES = 16;
    
    stage_t pipeline [NUM_INSTR];  // Tracks current stage of each instruction
    string instr_messages [NUM_INSTR][5];  // Stores messages for each stage
    int cycle_completed [NUM_INSTR];  // Stores cycle when instruction completes

    // Example Stage Tasks (Returning Messages)
    function string fetch_message(int instr_num, int cycle);
        return $sformatf("[FETCH] SUCCESS: PC_curr: 0x%0x, PC_next: 0x%0x, Instruction: 0x%0x @ Cycle: %0d",
                         instr_num*4, instr_num*4+2, instr_num*16, cycle);
    endfunction
    
    function string decode_message(int instr_num, int cycle);
        return $sformatf("[DECODE] SUCCESS: Opcode = 0b0001, Instr: SUB, rs = 0x1, rt = 0x2, rd = 0x1. @ Cycle: %0d", cycle);
    endfunction
    
    function string execute_message(int instr_num, int cycle);
        return $sformatf("[EXECUTE] SUCCESS: Input_A = 0x0002, Input_B = 0x0001, ALU_out = 0x0001, Z_set = 0, V_set = 0, N_set = 0. @ Cycle: %0d", cycle);
    endfunction

    function string memory_message(int instr_num, int cycle);
        return $sformatf("[MEMORY] SUCCESS: No memory access in this cycle. @ Cycle: %0d", cycle);
    endfunction

    function string writeback_message(int instr_num, int cycle);
        return $sformatf("[WRITE-BACK] SUCCESS: Register R1 written with data: 0x0001. @ Cycle: %0d", cycle);
    endfunction

    initial begin
        // Initialize pipeline states
        for (int i = 0; i < NUM_INSTR; i++) begin
            pipeline[i] = EMPTY;
            cycle_completed[i] = 0;
        end

        // Cycle-Based Execution
        for (int cycle = 1; cycle <= MAX_CYCLES; cycle++) begin
            #10; // Advance simulation time (10-time unit delay per cycle)

            // Move instructions through the pipeline
            for (int i = 0; i < NUM_INSTR; i++) begin
                if (pipeline[i] == EMPTY && (i == 0 || pipeline[i-1] >= DECODE)) begin
                    // First instruction enters Fetch, others follow if Decode is available
                    pipeline[i] = FETCH;
                end else if (pipeline[i] < WRITE_BACK) begin
                    // Move to next stage per cycle
                    if (i == 0 || (pipeline[i-1] > pipeline[i])) begin
                        pipeline[i] = stage_t'(pipeline[i] + 1);
                    end
                end

                // Store messages for each stage
                case (pipeline[i])
                    FETCH: instr_messages[i][0] = fetch_message(i, cycle);
                    DECODE: instr_messages[i][1] = decode_message(i, cycle);
                    EXECUTE: instr_messages[i][2] = execute_message(i, cycle);
                    MEMORY: instr_messages[i][3] = memory_message(i, cycle);
                    WRITE_BACK: begin
                        instr_messages[i][4] = writeback_message(i, cycle);
                        cycle_completed[i] = cycle;  // Mark cycle when WB completes
                    end
                endcase
            end

            // Print instruction log when it completes Write-back
            for (int i = 0; i < NUM_INSTR; i++) begin
                if (pipeline[i] == WRITE_BACK) begin
                    $display("# ========================================================");
                    $display("# | Instruction: SUB R1, R1, R2 | Completed At Cycle: %0d |", cycle_completed[i]);
                    $display("# ========================================================");
                    for (int j = 0; j < 5; j++) begin
                        if (instr_messages[i][j] != "") begin
                            $display("# %s", instr_messages[i][j]);
                        end
                    end
                    $display("# ========================================================");
                    
                    // Remove completed instruction
                    pipeline[i] = EMPTY;
                end
            end
        end
    end
endmodule
