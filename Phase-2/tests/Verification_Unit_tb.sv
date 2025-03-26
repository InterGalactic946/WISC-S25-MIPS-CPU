module tb_Verification_Unit;

  logic clk, rst, new_instr, stall, flush;
  string fetch_msg, decode_msg, full_instr_msg, execute_msg, mem_msg, wb_msg;

  // Instantiate the Verification Unit.
  Verification_Unit vu (
    .clk(clk),
    .rst(rst),
    .new_instr(new_instr),
    .stall(stall),
    .flush(flush),
    .fetch_msg(fetch_msg),
    .decode_msg(decode_msg),
    .full_instr_msg(full_instr_msg),
    .execute_msg(execute_msg),
    .mem_msg(mem_msg),
    .wb_msg(wb_msg)
  );

  // Clock generation: 10 time units period.
  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    // Initialize signals.
    rst = 1;
    new_instr = 0;
    stall = 0;
    flush = 0;
    fetch_msg = "";
    decode_msg = "";
    full_instr_msg = "";
    execute_msg = "";
    mem_msg = "";
    wb_msg = "";
    
    // Hold reset for a few cycles.
    #10;
    rst = 0;
    
    // -----------------------------------------------
    // Instruction 1: SUB R1, R1, R2 (Normal flow)
    // -----------------------------------------------
    // Cycle 1: New instruction fetched.
    #5;
    full_instr_msg = "SUB R1, R1, R2";
    new_instr = 1;
    fetch_msg = "[FETCH] SUCCESS: PC_curr: 0x000c, PC_next: 0x000e, Instruction: 0x1112 | Branch Predicted NOT Taken.";
    #5;
    new_instr = 0;
    
    // Cycle 2: Decode message.
    #5;
    decode_msg = "[DECODE] SUCCESS: Opcode = 0b0001, Instr: SUB, rs = 0x1, rt = 0x2, rd = 0x1.";
    #5;
    // Cycle 3: Execute.
    execute_msg = "[EXECUTE] SUCCESS: Input_A = 0x0002, Input_B = 0x0001, ALU_out = 0x0001, Z_set = 0, V_set = 0, N_set = 0.";
    #5;
    // Cycle 4: Memory.
    mem_msg = "[MEMORY] SUCCESS: No memory access in this cycle.";
    #5;
    // Cycle 5: Write-back.
    wb_msg = "[WRITE-BACK] SUCCESS: Register R1 written with data: 0x0001.";
    
    #10;  // Wait before next instruction.
    
    // -----------------------------------------------
    // Instruction 2: B 001, TARGET: 0x0016 (Branch with stalls)
    // -----------------------------------------------
    #5;
    full_instr_msg = "B 001, TARGET: 0x0016";
    new_instr = 1;
    fetch_msg = "[FETCH] SUCCESS: PC_curr: 0x0010, PC_next: 0x0012, Instruction: 0xc202 | Branch Predicted NOT Taken.";
    #5;
    new_instr = 0;
    
    // Cycle 3: First decode stall.
    #5;
    stall = 1; // Assert stall
    decode_msg = "[DECODE] STALL: Instruction stalled at decode due to Branch (B) hazard.";
    #5;
    // Cycle 4: Second decode stall.
    decode_msg = "[DECODE] STALL: Instruction stalled at decode due to Branch (B) hazard.";
    #5;
    // Cycle 5: Decode now succeeds.
    stall = 0;
    decode_msg = "[DECODE] SUCCESS: Flag state: ZF = 0, VF = 0, NF = 0. Branch (B) is actually taken. The actual target is: 0x0016.";
    #5;
    // Cycle 6: Execute.
    execute_msg = "[EXECUTE] SUCCESS: Input_A = 0x0000, Input_B = 0x0002, ALU_out = 0x0000, Z_set = 1, V_set = 0, N_set = 0.";
    #5;
    // Cycle 7: Memory.
    mem_msg = "[MEMORY] SUCCESS: No memory access in this cycle.";
    #5;
    // Cycle 8: Write-back.
    wb_msg = "[WRITE-BACK] SUCCESS: No register write in this cycle.";
    
    #10;
    
    // -----------------------------------------------
    // Instruction 3: ADD R2, R3, R4 (Flushed due to misprediction)
    // -----------------------------------------------
    // For flushed instruction, simulate fetch stalls first.
    #5;
    full_instr_msg = "FLUSHED";
    new_instr = 1;
    // Cycle 3: First fetch stall.
    #5;
    fetch_msg = "[FETCH] STALL: PC stalled due to propagated stall.";
    #5;
    // Cycle 4: Second fetch stall.
    fetch_msg = "[FETCH] STALL: PC stalled due to propagated stall.";
    #5;
    // Cycle 5: Normal fetch.
    fetch_msg = "[FETCH] SUCCESS: PC_curr: 0x0012, PC_next: 0x0014, Instruction: 0xc200 | Branch Predicted NOT Taken.";
    #5;
    new_instr = 0;
    
    // Cycle 6: Decode flush.
    #5;
    decode_msg = "[DECODE] FLUSH: Instruction flushed at decode (IF) due to mispredicted branch.";
    #5;
    // Cycle 7: Execute.
    execute_msg = "[EXECUTE] SUCCESS: Input_A = 0x0000, Input_B = 0x0000, ALU_out = 0x0000, Z_set = 1, V_set = 0, N_set = 0.";
    #5;
    // Cycle 8: Memory.
    mem_msg = "[MEMORY] SUCCESS: No memory access in this cycle.";
    #5;
    // Cycle 9: Write-back.
    wb_msg = "[WRITE-BACK] SUCCESS: No register write in this cycle.";
    
    #20;
    $finish;
  end

endmodule
