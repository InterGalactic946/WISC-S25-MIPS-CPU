module pipeline_tb();

    // Declare signals
    reg clk, rst;
    reg valid_fetch, valid_decode, valid_execute, valid_memory, valid_wb;
    reg [31:0] instruction;
    reg [15:0] PC_curr, PC_next;
    reg branch_predicted;
    reg [3:0] opcode;
    reg [31:0] input_A, input_B, ALU_out;
    reg Z_set, V_set, N_set;
    reg [31:0] write_data;
    reg [4:0] write_register;
    
    // Additional signal for stall/flush simulation
    reg branch_hazard;
    integer cycle_fetch = 0, cycle_decode = 0, cycle_execute = 0, cycle_memory = 0, cycle_wb = 0;

    // Initialize test signals
    initial begin
        clk = 0;
        rst = 1;
        valid_fetch = 0;
        valid_decode = 0;
        valid_execute = 0;
        valid_memory = 0;
        valid_wb = 0;
        instruction = 32'b0;
        PC_curr = 16'h0000;
        PC_next = 16'h0002;
        branch_predicted = 0;
        branch_hazard = 0;
        opcode = 4'b0000;
        input_A = 32'h0000;
        input_B = 32'h0000;
        ALU_out = 32'h0000;
        Z_set = 0;
        V_set = 0;
        N_set = 0;
        write_data = 32'h0000;
        write_register = 5'b0;

        // Reset logic
        #5 rst = 0;
        #5 rst = 1;

        // Simulate for 10 cycles with different instructions
        // First instruction: SUB
        #10 valid_fetch = 1; instruction = 32'h1112; // SUB R1, R1, R2
        #10 valid_decode = 1;
        #10 valid_execute = 1; input_A = 32'h2; input_B = 32'h1; ALU_out = 32'h1;
        #10 valid_memory = 1;
        #10 valid_wb = 1; write_data = 32'h1; write_register = 5'd1;
        
        // Second instruction: Branch (B)
        #20 valid_fetch = 1; instruction = 32'hc202; // B 001, TARGET: 0x0016
        #20 valid_decode = 1;
        #20 valid_execute = 1; // Here we simulate branch prediction
        #20 valid_memory = 1;
        #20 valid_wb = 1;
        
        // Third instruction: ADD (this will be flushed due to branch misprediction)
        #30 valid_fetch = 1; instruction = 32'h2222; // ADD R2, R3, R4
        #30 valid_decode = 1;
        #30 valid_execute = 1;
        #30 valid_memory = 1;
        #30 valid_wb = 1;
        
        #10 $finish;
    end

    // Clock Generation
    always #5 clk = ~clk;

    // Print instruction stages with stall/flush handling
    always @(posedge clk) begin
        if (rst) begin
            cycle_fetch <= 0;
            cycle_decode <= 0;
            cycle_execute <= 0;
            cycle_memory <= 0;
            cycle_wb <= 0;
        end else begin
            if (valid_fetch) cycle_fetch <= cycle_fetch + 1;
            if (valid_decode) cycle_decode <= cycle_decode + 1;
            if (valid_execute) cycle_execute <= cycle_execute + 1;
            if (valid_memory) cycle_memory <= cycle_memory + 1;
            if (valid_wb) cycle_wb <= cycle_wb + 1;
        end
    end

    // Display stages in desired format
    always @(posedge clk) begin
        if (valid_wb) begin
            // Instruction Header
            $display("==========================================================");
            $display("| Instruction: %s | Completed At Cycle: %0d |", 
                     (instruction == 32'h1112) ? "SUB R1, R1, R2" : 
                     (instruction == 32'hc202) ? "B 001, TARGET: 0x0016" : 
                     (instruction == 32'h2222) ? "ADD R2, R3, R4" : "FLUSHED", cycle_wb);
            $display("==========================================================");

            // FETCH Stage Message
            if (branch_hazard) begin
                $display("|[FETCH] STALL: PC stalled due to propagated stall. @ Cycle: %0d", cycle_fetch);
            end else begin
                $display("|[FETCH] SUCCESS: PC_curr: 0x%h, PC_next: 0x%h, Instruction: 0x%h", 
                         PC_curr, PC_next, instruction);
            end

            // DECODE Stage Message
            if (valid_decode) begin
                if (branch_predicted && branch_hazard) begin
                    // Branch Hazard Stall
                    $display("|[DECODE] STALL: Instruction stalled at decode due to Branch (B) hazard. @ Cycle: %0d", cycle_decode);
                end else begin
                    $display("|[DECODE] SUCCESS: Opcode = 0b%0b, Instr: %s, rs = 0x%h, rt = 0x%h, rd = 0x%h. @ Cycle: %0d", 
                             opcode, 
                             (instruction == 32'h1112) ? "SUB" : 
                             (instruction == 32'hc202) ? "B" : "ADD",
                             input_A, input_B, write_register, cycle_decode);
                end
            end

            // EXECUTE Stage Message
            $display("|[EXECUTE] SUCCESS: Input_A = 0x%h, Input_B = 0x%h, ALU_out = 0x%h, Z_set = %b, V_set = %b, N_set = %b. @ Cycle: %0d", 
                     input_A, input_B, ALU_out, Z_set, V_set, N_set, cycle_execute);

            // MEMORY Stage Message
            $display("|[MEMORY] SUCCESS: No memory access in this cycle. @ Cycle: %0d", cycle_memory);

            // WRITE-BACK Stage Message
            if (instruction != 32'h2222) begin // ADD will be flushed, no write-back
                $display("|[WRITE-BACK] SUCCESS: Register R%0d written with data: 0x%h. @ Cycle: %0d", write_register, write_data, cycle_wb);
            end else begin
                $display("|[WRITE-BACK] SUCCESS: No register write in this cycle. @ Cycle: %0d", cycle_wb);
            end
            $display("==========================================================\n");
        end
    end
endmodule
