module Verification_Unit_tb();
    
    // Clock and Reset
    logic clk;
    logic rst;
    
    // String messages for each stage
    string if_id_msg, decode_msg, instruction_full_msg;
    string id_ex_msg, execute_msg;
    string ex_mem_msg, mem_msg;
    string mem_wb_msg, wb_msg;
    string pc_stall_msg, if_id_stall_msg;
    string if_flush_msg, id_flush_msg;
    
    // Control signals
    logic stall, flush;
    
    // Instantiate the Verification Unit
    Verification_Unit dut (
        .clk(clk), .rst(rst),
        .if_id_msg(if_id_msg), .decode_msg(decode_msg),
        .instruction_full_msg(instruction_full_msg),
        .id_ex_msg(id_ex_msg), .execute_msg(execute_msg),
        .ex_mem_msg(ex_mem_msg), .mem_msg(mem_msg),
        .mem_wb_msg(mem_wb_msg), .wb_msg(wb_msg),
        .pc_stall_msg(pc_stall_msg), .if_id_stall_msg(if_id_stall_msg),
        .if_flush_msg(if_flush_msg), .id_flush_msg(id_flush_msg),
        .stall(stall), .flush(flush)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Testbench Logic
    initial begin
        // Initialize Signals
        clk = 0;
        rst = 1;
        stall = 0;
        flush = 0;
        if_id_msg = "";
        decode_msg = "";
        instruction_full_msg = "";
        id_ex_msg = "";
        execute_msg = "";
        ex_mem_msg = "";
        mem_msg = "";
        mem_wb_msg = "";
        wb_msg = "";
        pc_stall_msg = "";
        if_id_stall_msg = "";
        if_flush_msg = "";
        id_flush_msg = "";

        // Apply Reset
        #10 rst = 0;

        // Cycle 1: Fetch First Instruction
        if_id_msg = "Fetched ADD R1, R2, R3";
        instruction_full_msg = "ADD R1, R2, R3";
        #10;

        // Cycle 2: Decode Stage
        decode_msg = "Decoded ADD R1, R2, R3";
        #10;

        // Cycle 3: Execute Stage
        id_ex_msg = "Operands R2=5, R3=3";
        execute_msg = "Executing ADD: 5 + 3";
        #10;

        // Cycle 4: Memory Stage
        ex_mem_msg = "No Memory Access";
        mem_msg = "Skipping Memory Stage";
        #10;

        // Cycle 5: Write-back Stage
        mem_wb_msg = "WB: R1 = 8";
        wb_msg = "Register Write: R1 = 8";
        #10;

        // Cycle 6: Introduce a Stall
        stall = 1;
        pc_stall_msg = "STALL: Data Hazard Detected";
        #10;

        // Cycle 7: Remove Stall, Continue Execution
        stall = 0;
        #10;

        // Cycle 8: Introduce a Flush
        flush = 1;
        if_flush_msg = "FLUSH: Branch Misprediction";
        #10;

        // Cycle 9: Remove Flush, Resume Execution
        flush = 0;
        #10;

        // End Simulation
        $stop();
    end
endmodule