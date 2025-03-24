module Verification_Unit (
    input  logic        clk, rst,                // Clock and reset signals
    input  string       fetch_msg,               // Fetch stage message
    input  string       if_id_msg,               // IF/ID stage message
    input  string       decode_msg,              // Decode stage message
    input  string       instruction_full_msg,    // Full instruction message
    input  string       id_ex_msg,               // ID/EX stage message
    input  string       execute_msg,             // Execute stage message
    input  string       ex_mem_msg,              // EX/MEM stage message
    input  string       mem_msg,                 // Memory stage message
    input  string       mem_wb_msg,              // MEM/WB stage message
    input  string       wb_msg,                  // WB stage message
    input  string       flush_msg,               // Flush message
    input  logic        stall,                   // Stall signal
    input  logic        flush                    // Flush signal
);

    /////////////////////////////////////////
    // Internal Storage for Pipeline Stages //
    /////////////////////////////////////////
    typedef struct {
        string instr_msg;   // Full instruction message
        string fetch;        // Fetch message
        string if_id;        // IF/ID message
        string decode[2];    // Array to store Decode stage messages
        string id_ex;        // ID/EX message
        string execute;      // Execute message
        string ex_mem;       // EX/MEM message
        string mem;          // Memory stage message
        string mem_wb;       // MEM/WB message
        string wb;           // WB message
        string stall[5];     // Allow up to 5 stall messages
        string flush;        // Flush message
        integer fetch_cycle;
        integer if_id_cycle;
        integer decode_cycle;
        integer id_ex_cycle;
        integer execute_cycle;
        integer ex_mem_cycle;
        integer mem_cycle;
        integer mem_wb_cycle;
        integer wb_cycle;
    } pipeline_t;

    pipeline_t instr_queue[0:31];  // FIFO queue for 32 in-flight instructions
    integer head, tail;    // Head and tail pointers for queue
    integer i;                     // Loop variable
    integer wb_valid_counter;  // Counter for WB valid
    logic wb_valid;
    
    //////////////////////////////////////////////
    // Sequential Block: Store Messages Per Stage //
    //////////////////////////////////////////////
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_valid_counter <= 0;  // Reset the counter on reset
            head <= 0;
            tail <= 0;
        end else if (wb_valid)          
            head <= head + 1;  // Move queue forward
        else begin
            if (fetch_msg != "") begin
                instr_queue[tail].fetch <= fetch_msg;
                instr_queue[tail].fetch_cycle <= $time / 10;
            end
            if (if_id_msg != "") begin
                instr_queue[tail].if_id <= if_id_msg;
                instr_queue[tail].if_id_cycle <= $time / 10;
            end
            if (decode_msg != "") begin
                instr_queue[tail].decode[0] <= decode_msg;
                instr_queue[tail].decode[1] <= instruction_full_msg;
                instr_queue[tail].decode_cycle <= $time / 10;
            end
            if (id_ex_msg != "") begin
                instr_queue[tail].id_ex <= id_ex_msg;
                instr_queue[tail].id_ex_cycle <= $time / 10;
            end
            if (execute_msg != "") begin
                instr_queue[tail].execute <= execute_msg;
                instr_queue[tail].execute_cycle <= $time / 10;
            end
            if (ex_mem_msg != "") begin
                instr_queue[tail].ex_mem <= ex_mem_msg;
                instr_queue[tail].ex_mem_cycle <= $time / 10;
            end
            if (mem_msg != "") begin
                instr_queue[tail].mem <= mem_msg;
                instr_queue[tail].mem_cycle <= $time / 10;
            end
            if (mem_wb_msg != "") begin
                instr_queue[tail].mem_wb <= mem_wb_msg;
                instr_queue[tail].mem_wb_cycle <= $time / 10;
            end
            if (wb_msg != "") begin
                instr_queue[tail].wb <= wb_msg;
                instr_queue[tail].wb_cycle <= $time / 10;
            end
            if (flush_msg != "") begin
                instr_queue[tail].flush <= flush_msg;
            end
            if (!stall && !flush) begin
                tail <= tail + 1;
                wb_valid_counter <= wb_valid_counter + 1;
            end
        end
    end

    assign wb_valid = (wb_valid_counter % 5 == 0);

    /////////////////////////////////////////
    // Print Pipeline Messages at WB Stage //
    /////////////////////////////////////////
    always_ff @(posedge clk) begin
        if (!rst && wb_valid && wb_valid_counter > 0) begin
            $display("=====================================================");
            $display("| Instruction: %s | Clock Cycle: %0t |", instr_queue[head].decode[1], $time/10);
            $display("=====================================================");
            
            if (instr_queue[head].fetch != "")
                $display("|%s @ Cycle: %0t", instr_queue[head].fetch, instr_queue[head].fetch_cycle);
            if (instr_queue[head].if_id != "")
                $display("|%s @ Cycle: %0t", instr_queue[head].if_id, instr_queue[head].if_id_cycle);
            if (instr_queue[head].decode[0] != "")
                $display("|%s @ Cycle: %0t", instr_queue[head].decode[0], instr_queue[head].decode_cycle);
            if (instr_queue[head].id_ex != "")
                $display("|%s @ Cycle: %0t", instr_queue[head].id_ex, instr_queue[head].id_ex_cycle);
            if (instr_queue[head].execute != "")
                $display("|%s @ Cycle: %0t", instr_queue[head].execute, instr_queue[head].execute_cycle);
            if (instr_queue[head].ex_mem != "")
                $display("|%s @ Cycle: %0t", instr_queue[head].ex_mem, instr_queue[head].ex_mem_cycle);
            if (instr_queue[head].mem != "")
                $display("|[MEMORY] %s @ Cycle: %0t", instr_queue[head].mem, instr_queue[head].mem_cycle);
            if (instr_queue[head].wb != "")
                $display("|[WRITE-BACK] %s @ Cycle: %0t", instr_queue[head].wb, instr_queue[head].wb_cycle);
        end
    end

endmodule
