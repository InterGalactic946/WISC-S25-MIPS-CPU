module Verification_Unit (
  input  logic       clk,
  input  logic       rst,
  // Pulse this high for one cycle when a new instruction is fetched.
  input  logic       new_instr,
  // Stall and flush signals (if needed)
  input  logic       stall,
  input  logic       flush,
  // Stage messages (driven as one‑cycle pulses when valid)
  input  string      fetch_msg,
  input  string      decode_msg,
  input  string      full_instr_msg, // e.g. "SUB R1, R1, R2"
  input  string      execute_msg,
  input  string      mem_msg,
  input  string      wb_msg
);

  // Structure to hold debug messages for one instruction.
  typedef struct {
    string fetch_msgs[$];  // Dynamic array for fetch stage messages.
    int    fetch_cycle;    // Cycle when the last fetch message was captured.
    string decode_msgs[$]; // Dynamic array for decode stage messages.
    int    decode_cycle;
    string execute_msg;    // Single execute message.
    int    execute_cycle;
    string mem_msg;        // Single memory message.
    int    mem_cycle;
    string wb_msg;         // Single write-back message.
    int    wb_cycle;
    string full_instr;     // Complete instruction text.
    bit    printed;        // Flag to ensure one-time printing.
  } debug_info_t;

  // Dynamic array to hold one record per instruction.
  debug_info_t pipeline_msgs[$];
  int instr_index;

  // On reset or when a new instruction arrives, create a new record.
  always @(posedge clk) begin
    if (rst) begin
      pipeline_msgs.delete();
      instr_index <= 0;
    end else if (new_instr) begin
      pipeline_msgs.push_back('{
         fetch_msgs: {},
         fetch_cycle: 0,
         decode_msgs: {},
         decode_cycle: 0,
         execute_msg: "",
         execute_cycle: 0,
         mem_msg: "",
         mem_cycle: 0,
         wb_msg: "",
         wb_cycle: 0,
         full_instr: full_instr_msg,
         printed: 0
      });
      instr_index++;
    end
  end

  // Capture stage messages for the current instruction.
  always @(posedge clk) begin
    if (!rst && (instr_index > 0)) begin
      // For FETCH: Only add if nonempty and different from last stored message.
      if (fetch_msg != "") begin
         if (pipeline_msgs[instr_index-1].fetch_msgs.size() == 0 ||
             fetch_msg != pipeline_msgs[instr_index-1].fetch_msgs[pipeline_msgs[instr_index-1].fetch_msgs.size()-1]) begin
            pipeline_msgs[instr_index-1].fetch_msgs.push_back(fetch_msg);
            pipeline_msgs[instr_index-1].fetch_cycle = $time / 10;
         end
      end

      // For DECODE: Same approach.
      if (decode_msg != "") begin
         if (pipeline_msgs[instr_index-1].decode_msgs.size() == 0 ||
             decode_msg != pipeline_msgs[instr_index-1].decode_msgs[pipeline_msgs[instr_index-1].decode_msgs.size()-1]) begin
            pipeline_msgs[instr_index-1].decode_msgs.push_back(decode_msg);
            pipeline_msgs[instr_index-1].decode_cycle = $time / 10;
         end
      end

      // For EXECUTE, MEMORY, and WRITE-BACK assume one pulse each.
      if ((execute_msg != "") && (pipeline_msgs[instr_index-1].execute_msg == "")) begin
         pipeline_msgs[instr_index-1].execute_msg = execute_msg;
         pipeline_msgs[instr_index-1].execute_cycle = $time / 10;
      end
      if ((mem_msg != "") && (pipeline_msgs[instr_index-1].mem_msg == "")) begin
         pipeline_msgs[instr_index-1].mem_msg = mem_msg;
         pipeline_msgs[instr_index-1].mem_cycle = $time / 10;
      end
      if ((wb_msg != "") && (pipeline_msgs[instr_index-1].wb_msg == "")) begin
         pipeline_msgs[instr_index-1].wb_msg = wb_msg;
         pipeline_msgs[instr_index-1].wb_cycle = $time / 10;
      end

      // When a write-back message is present and we haven't printed the record yet, print it.
      if ((pipeline_msgs[instr_index-1].wb_msg != "") && !pipeline_msgs[instr_index-1].printed) begin
         pipeline_msgs[instr_index-1].printed = 1;
         $display("==========================================================");
         $display("| Instruction: %s | Completed At Cycle: %0d |", 
                  pipeline_msgs[instr_index-1].full_instr, pipeline_msgs[instr_index-1].wb_cycle);
         $display("==========================================================");
         foreach (pipeline_msgs[instr_index-1].fetch_msgs[i])
           $display("|%s @ Cycle: %0d", pipeline_msgs[instr_index-1].fetch_msgs[i], pipeline_msgs[instr_index-1].fetch_cycle);
         foreach (pipeline_msgs[instr_index-1].decode_msgs[i])
           $display("|%s @ Cycle: %0d", pipeline_msgs[instr_index-1].decode_msgs[i], pipeline_msgs[instr_index-1].decode_cycle);
         $display("|%s @ Cycle: %0d", pipeline_msgs[instr_index-1].execute_msg, pipeline_msgs[instr_index-1].execute_cycle);
         $display("|%s @ Cycle: %0d", pipeline_msgs[instr_index-1].mem_msg, pipeline_msgs[instr_index-1].mem_cycle);
         $display("|%s @ Cycle: %0d", pipeline_msgs[instr_index-1].wb_msg, pipeline_msgs[instr_index-1].wb_cycle);
         $display("==========================================================\n");
      end
    end
  end

endmodule
