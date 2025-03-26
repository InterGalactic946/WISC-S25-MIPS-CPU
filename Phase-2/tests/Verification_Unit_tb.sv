module Verification_Unit_tb();

  // Clock and reset
  logic clk, rst;
  // Control signals for stall/flush and new instruction detection.
  logic new_instr, stall, flush;
  // Pipeline stage messages (as strings).
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

  // Test stimulus:
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
    // At cycle 1, new instruction fetched.
    #5;
    full_instr_msg = "SUB R1, R1, R2";
    new_instr = 1;
    fetch_msg = "[FETCH] SUCCESS: PC_curr: 0x000c, PC_next: 0x000e, Instruction: 0x1112 | Branch Predicted NOT Taken.";
    #5;
    new_instr = 0;  // new_instr is a one-cycle pulse.

    // Cycle 2: Normal decode.
    #5;
    decode_msg = "[DECODE] SUCCESS: Opcode = 0b0001, Instr: SUB, rs = 0x1, rt = 0x2, rd = 0x1.";
    
    // Cycle 3: Execute stage.
    #5;
    execute_msg = "[EXECUTE] SUCCESS: Input_A = 0x0002, Input_B = 0x0001, ALU_out = 0x0001, Z_set = 0, V_set = 0, N_set = 0.";
    
    // Cycle 4: Memory stage.
    #5;
    mem_msg = "[MEMORY] SUCCESS: No memory access in this cycle.";
    
    // Cycle 5: Write-back stage.
    #5;
    wb_msg = "[WRITE-BACK] SUCCESS: Register R1 written with data: 0x0001.";
    
    // Wait before next instruction.
    #10;
    
    // -----------------------------------------------
    // Instruction 2: B 001, TARGET: 0x0016 (Branch with stalls)
    // -----------------------------------------------
    // At cycle 2 for new instruction.
    #5;
    full_instr_msg = "B 001, TARGET: 0x0016";
    new_instr = 1;
    fetch_msg = "[FETCH] SUCCESS: PC_curr: 0x0010, PC_next: 0x0012, Instruction: 0xc202 | Branch Predicted NOT Taken.";
    #5;
    new_instr = 0;
    
    // Cycle 3: First decode stall.
    stall = 1;
    #5;
    decode_msg = "[DECODE] STALL: Instruction stalled at decode due to Branch (B) hazard.";
    // Cycle 4: Second decode stall.
    #5;
    decode_msg = "[DECODE] STALL: Instruction stalled at decode due to Branch (B) hazard.";
    // Cycle 5: Decode stage now succeeds.
    stall = 0;
    #5;
    decode_msg = "[DECODE] SUCCESS: Flag state: ZF = 0, VF = 0, NF = 0. Branch (B) is actually taken. The actual target is: 0x0016.";
    
    // Cycle 6: Execute stage.
    #5;
    execute_msg = "[EXECUTE] SUCCESS: Input_A = 0x0000, Input_B = 0x0002, ALU_out = 0x0000, Z_set = 1, V_set = 0, N_set = 0.";
    // Cycle 7: Memory stage.
    #5;
    mem_msg = "[MEMORY] SUCCESS: No memory access in this cycle.";
    // Cycle 8: Write-back stage (no register write).
    #5;
    wb_msg = "[WRITE-BACK] SUCCESS: No register write in this cycle.";
    
    #10;
    
    // -----------------------------------------------
    // Instruction 3: ADD R2, R3, R4 (Flushed due to misprediction)
    // -----------------------------------------------
    // For flushed instruction, we simulate fetch stalls before a normal fetch.
    #5;
    full_instr_msg = "FLUSHED";
    new_instr = 1;
    // On cycle 3, a stall message is generated.
    fetch_msg = "[FETCH] STALL: PC stalled due to propagated stall.";
    #5;
    // On cycle 4, another fetch stall.
    fetch_msg = "[FETCH] STALL: PC stalled due to propagated stall.";
    #5;
    // On cycle 5, a normal fetch message.
    fetch_msg = "[FETCH] SUCCESS: PC_curr: 0x0012, PC_next: 0x0014, Instruction: 0xc200 | Branch Predicted NOT Taken.";
    #5;
    new_instr = 0;
    
    // Cycle 6: Decode flush message.
    #5;
    decode_msg = "[DECODE] FLUSH: Instruction flushed at decode (IF) due to mispredicted branch.";
    
    // Cycle 7: Execute stage.
    #5;
    execute_msg = "[EXECUTE] SUCCESS: Input_A = 0x0000, Input_B = 0x0000, ALU_out = 0x0000, Z_set = 1, V_set = 0, N_set = 0.";
    // Cycle 8: Memory stage.
    #5;
    mem_msg = "[MEMORY] SUCCESS: No memory access in this cycle.";
    // Cycle 9: Write-back stage.
    #5;
    wb_msg = "[WRITE-BACK] SUCCESS: No register write in this cycle.";
    
    #20;
    $finish;
  end

endmodule
