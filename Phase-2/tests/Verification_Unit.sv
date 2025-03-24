///////////////////////////////////////////////////////////
// Verification_Unit.sv: Verification Unit Module        //  
//                                                       //
// This module tracks and verifies debug messages for    //
// each instruction as it moves through the pipeline.    //
// Messages are stored and printed at the WB stage.      //
///////////////////////////////////////////////////////////

module Verification_Unit (
    input  logic        clk, rst,         // Clock and reset signals
    input  logic        wb_done,          // Signal indicating WB stage completion
    input  string       fetch_msg,        // Fetch stage message
    input  string       if_id_msg,        // IF/ID stage message
    input  string       decode_msg,       // Decode stage message
    input  string       id_ex_msg,        // ID/EX stage message
    input  string       execute_msg,      // Execute stage message
    input  string       ex_mem_msg,       // EX/MEM stage message
    input  string       mem_msg,          // Memory stage message
    input  string       mem_wb_msg,       // MEM/WB stage message
    input  string       wb_msg,           // WB stage message
    input  string       stall_msg,        // Stall message (if any)
    input  string       flush_msg         // Flush message (if any)
);

    /////////////////////////////////////////
    // Internal Storage for Pipeline Stages //
    /////////////////////////////////////////
    typedef struct {
        string instr_msg;   // Full instruction message
        string fetch;
        string if_id;
        string decode;
        string id_ex;
        string execute;
        string ex_mem;
        string mem;
        string mem_wb;
        string wb;
        string stall[5];    // Allow up to 5 stall messages
        string flush;
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
    integer head = 0, tail = 0;    // Head and tail pointers for queue
    integer i;                     // Loop variable

    //////////////////////////////////////////////
    // Sequential Block: Store Messages Per Stage //
    //////////////////////////////////////////////
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            head <= 0;
            tail <= 0;
        end else begin
            if (fetch_msg != "") begin
                instr_queue[tail].fetch = fetch_msg;
                instr_queue[tail].fetch_cycle = $time / 10;
            end
            if (if_id_msg != "") begin
                instr_queue[tail].if_id = if_id_msg;
                instr_queue[tail].if_id_cycle = $time / 10;
            end
            if (decode_msg != "") begin
                instr_queue[tail].decode = decode_msg;
                instr_queue[tail].decode_cycle = $time / 10;
            end
            if (id_ex_msg != "") begin
                instr_queue[tail].id_ex = id_ex_msg;
                instr_queue[tail].id_ex_cycle = $time / 10;
            end
            if (execute_msg != "") begin
                instr_queue[tail].execute = execute_msg;
                instr_queue[tail].execute_cycle = $time / 10;
            end
            if (ex_mem_msg != "") begin
                instr_queue[tail].ex_mem = ex_mem_msg;
                instr_queue[tail].ex_mem_cycle = $time / 10;
            end
            if (mem_msg != "") begin
                instr_queue[tail].mem = mem_msg;
                instr_queue[tail].mem_cycle = $time / 10;
            end
            if (mem_wb_msg != "") begin
                instr_queue[tail].mem_wb = mem_wb_msg;
                instr_queue[tail].mem_wb_cycle = $time / 10;
            end
            if (wb_msg != "") begin
                instr_queue[tail].wb = wb_msg;
                instr_queue[tail].wb_cycle = $time / 10;
            end
            if (stall_msg != "") begin
                for (i = 0; i < 5; i++) begin
                    if (instr_queue[tail].stall[i] == "") begin
                        instr_queue[tail].stall[i] = stall_msg;
                        break;
                    end
                end
            end
            if (flush_msg != "") begin
                instr_queue[tail].flush = flush_msg;
            end
        end
    end

    /////////////////////////////////////////
    // Print Pipeline Messages at WB Stage //
    /////////////////////////////////////////
    always_ff @(posedge clk) begin
        if (!rst && wb_done) begin
            $display("=====================================================");
            $display("| Instruction: %s | Clock Cycle: %0t |", instr_queue[head].decode, $time/10);
            $display("=====================================================");
            
            if (instr_queue[head].fetch != "")
                $display("|[FETCH] %s @ Cycle: %0t", instr_queue[head].fetch, instr_queue[head].fetch_cycle);
            if (instr_queue[head].if_id != "")
                $display("|[IF_ID] %s @ Cycle: %0t", instr_queue[head].if_id, instr_queue[head].if_id_cycle);
            if (instr_queue[head].decode != "")
                $display("|[DECODE] %s @ Cycle: %0t", instr_queue[head].decode, instr_queue[head].decode_cycle);
            if (instr_queue[head].id_ex != "")
                $display("|[ID_EX] %s @ Cycle: %0t", instr_queue[head].id_ex, instr_queue[head].id_ex_cycle);
            if (instr_queue[head].execute != "")
                $display("|[EXECUTE] %s @ Cycle: %0t", instr_queue[head].execute, instr_queue[head].execute_cycle);
            if (instr_queue[head].ex_mem != "")
                $display("|[EX_MEM] %s @ Cycle: %0t", instr_queue[head].ex_mem, instr_queue[head].ex_mem_cycle);
            if (instr_queue[head].mem != "")
                $display("|[MEMORY] %s @ Cycle: %0t", instr_queue[head].mem, instr_queue[head].mem_cycle);
            if (instr_queue[head].mem_wb != "")
                $display("|[MEM_WB] %s @ Cycle: %0t", instr_queue[head].mem_wb, instr_queue[head].mem_wb_cycle);
            if (instr_queue[head].wb != "")
                $display("|[WRITE-BACK] %s @ Cycle: %0t", instr_queue[head].wb, instr_queue[head].wb_cycle);

            for (i = 0; i < 5; i++) begin
                if (instr_queue[head].stall[i] != "")
                    $display("|[STALL] %s", instr_queue[head].stall[i]);
            end

            if (instr_queue[head].flush != "")
                $display("|[FLUSH] %s", instr_queue[head].flush);
            
            $display("=====================================================");
            
            head <= head + 1;  // Move queue forward
        end
    end

endmodule
