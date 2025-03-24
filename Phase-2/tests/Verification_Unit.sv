always @(posedge clk) begin
    if (rst) begin
        fetch_id <= 0;
        decode_id <= 0;
        execute_id <= 0;
        memory_id <= 0;
        wb_id <= 0;
        valid_fetch <= 1;
        valid_decode <= 0;
        valid_execute <= 0;
        valid_memory <= 0;
        valid_wb <= 0;
    end else begin
        if (!stall) begin
            fetch_id <= fetch_id + 1;
            valid_fetch <= 1;
        end
        
        decode_id <= fetch_id;
        execute_id <= decode_id;
        memory_id <= execute_id;
        wb_id <= memory_id;

        valid_decode <= valid_fetch;
        valid_execute <= valid_decode;
        valid_memory <= valid_execute;
        valid_wb <= valid_memory;
    end
end

// Add messages to the pipeline, ensuring stalls and flushes are respected
always @(posedge clk) begin
    if (!rst) begin
        // For decode stage, handle message updates only if valid and not stalled
        if (valid_decode && !stall) begin
            pipeline_msgs[decode_id].decode_msg[0] <= decode_msg;
            pipeline_msgs[decode_id].decode_msg[1] <= instruction_full_msg;
            pipeline_msgs[decode_id].if_id_msg <= if_id_msg;
            pipeline_msgs[decode_id].if_id_cycle <= $time / 10;
            pipeline_msgs[decode_id].decode_cycle <= $time / 10;
        end
        // For execute stage, handle message updates only if valid and not stalled
        if (valid_execute && !stall) begin
            pipeline_msgs[execute_id].id_ex_msg <= id_ex_msg;
            pipeline_msgs[execute_id].execute_msg <= execute_msg;
            pipeline_msgs[execute_id].id_ex_cycle <= $time / 10;
            pipeline_msgs[execute_id].execute_cycle <= $time / 10;
        end
        // For memory stage, handle message updates only if valid and not stalled
        if (valid_memory && !stall) begin
            pipeline_msgs[memory_id].ex_mem_msg <= ex_mem_msg;
            pipeline_msgs[memory_id].ex_mem_cycle <= $time / 10;
            pipeline_msgs[memory_id].memory_msg <= mem_msg;
            pipeline_msgs[memory_id].memory_cycle <= $time / 10;
        end
        // For write-back stage, handle message updates only if valid and not stalled or flushed
        if (valid_wb && !stall && !flush) begin
            pipeline_msgs[wb_id].mem_wb_msg = mem_wb_msg;
            pipeline_msgs[wb_id].mem_wb_cycle = $time / 10;
            pipeline_msgs[wb_id].wb_msg = wb_msg;
            pipeline_msgs[wb_id].wb_cycle = $time / 10;
        end
    end
end

// Display stall or flush messages
always @(posedge clk) begin
    if (!rst) begin
        if (stall) begin
            if (pc_stall_msg !== "") begin
                $display("\n=====================================================");
                $display(pc_stall_msg);
                $display("=====================================================\n");
            end
            if (if_id_stall_msg !== "") begin
                $display("\n=====================================================");
                $display(if_id_stall_msg);
                $display("=====================================================\n");
            end
        end
        if (flush) begin
            if (if_flush_msg !== "") begin
                $display("\n=====================================================");
                $display(if_flush_msg);
                $display("=====================================================\n");
            end
            if (id_flush_msg !== "") begin
                $display("\n=====================================================");
                $display(id_flush_msg);
                $display("=====================================================\n");
            end
        end
    end
end

// Print the message for each instruction, considering stall/flush
always @(posedge clk) begin
    if (!rst && valid_wb) begin
        $display("==========================================================");
        $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline_msgs[wb_id].decode_msg[1], $time / 10);
        $display("==========================================================");
        if (valid_fetch) $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].if_id_msg, pipeline_msgs[wb_id].if_id_cycle);
        if (valid_decode) $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].decode_msg[0], pipeline_msgs[wb_id].decode_cycle);
        if (valid_execute) $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].id_ex_msg, pipeline_msgs[wb_id].id_ex_cycle);
        if (valid_memory) $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].execute_msg, pipeline_msgs[wb_id].execute_cycle);
        if (valid_memory) $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].ex_mem_msg, pipeline_msgs[wb_id].ex_mem_cycle);
        if (valid_memory) $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].memory_msg, pipeline_msgs[wb_id].memory_cycle);
        if (valid_wb) $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].mem_wb_msg, pipeline_msgs[wb_id].mem_wb_cycle);
        if (valid_wb) $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].wb_msg, pipeline_msgs[wb_id].wb_cycle);
        $display("==========================================================\n");
    end
end
