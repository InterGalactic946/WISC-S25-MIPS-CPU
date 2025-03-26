module Verification_Unit (
  input  logic       clk,
  input  logic       rst,
  // Pulse this high for one cycle when a new instruction is fetched.
  input  logic       new_instr,
  // Stall and flush signals to indicate abnormal conditions.
  input  logic       stall,
  input  logic       flush,
  // String messages provided by each pipeline stage on every cycle.
  input  string      fetch_msg,
  input  string      decode_msg,
  input  string      full_instr_msg, // e.g. "SUB R1, R1, R2"
  input  string      execute_msg,
  input  string      mem_msg,
  input  string      wb_msg
);

  // Structure to hold messages for one instruction.
  typedef struct {
    string fetch_msgs[$];  // dynamic array of fetch messages
    int    fetch_cycle;    // Last cycle when a fetch message was received.
    string decode_msgs[$]; // dynamic array of decode messages
    int    decode_cycle;
    string execute_msg;
    int    execute_cycle;
    string mem_msg;
    int    mem_cycle;
    string wb_msg;
    int    wb_cycle;
    string full_instr;     // The complete instruction text.
  } debug_info_t;

  // Dynamic array to hold records for each instruction.
  debug_info_t pipeline_msgs[$];
  int instr_index;

  // On reset, clear stored messages.
  always @(posedge clk) begin
    if (rst) begin
      pipeline_msgs.delete();
      instr_index <= 0;
    end else if (new_instr) begin
      // When a new instruction is fetched, push a new record.
      pipeline_msgs.push_back('{
         fetch_msgs: {},         // use {} to denote an empty dynamic array
         fetch_cycle: 0,
         decode_msgs: {},
         decode_cycle: 0,
         execute_msg: "",
         execute_cycle: 0,
         mem_msg: "",
         mem_cycle: 0,
         wb_msg: "",
         wb_cycle: 0,
         full_instr: full_instr_msg
      });
      instr_index++;
    end
  end

  // On each clock cycle, append any stage message (if nonempty)
  // to the current instruction record.
  always @(posedge clk) begin
    if (!rst && (instr_index > 0)) begin
      // Append fetch message (even if stall is active).
      if (fetch_msg != "") begin
         pipeline_msgs[instr_index-1].fetch_msgs.push_back(fetch_msg);
         pipeline_msgs[instr_index-1].fetch_cycle = $time / 10;
      end
      // Append decode message.
      if (decode_msg != "") begin
         pipeline_msgs[instr_index-1].decode_msgs.push_back(decode_msg);
         pipeline_msgs[instr_index-1].decode_cycle = $time / 10;
      end
      // Capture execute, memory, and write-back messages.
      if (execute_msg != "") begin
         pipeline_msgs[instr_index-1].execute_msg = execute_msg;
         pipeline_msgs[instr_index-1].execute_cycle = $time / 10;
      end
      if (mem_msg != "") begin
         pipeline_msgs[instr_index-1].mem_msg = mem_msg;
         pipeline_msgs[instr_index-1].mem_cycle = $time / 10;
      end
      if (wb_msg != "") begin
         pipeline_msgs[instr_index-1].wb_msg = wb_msg;
         pipeline_msgs[instr_index-1].wb_cycle = $time / 10;
         // When the write-back message is received, assume the instruction is complete.
         // Print the entire record.
         $display("==========================================================");
         $display("| Instruction: %s | Completed At Cycle: %0d |", 
                  pipeline_msgs[instr_index-1].full_instr, pipeline_msgs[instr_index-1].wb_cycle);
         $display("==========================================================");
         foreach(pipeline_msgs[instr_index-1].fetch_msgs[i])
           $display("|%s @ Cycle: %0d", pipeline_msgs[instr_index-1].fetch_msgs[i], pipeline_msgs[instr_index-1].fetch_cycle);
         foreach(pipeline_msgs[instr_index-1].decode_msgs[i])
           $display("|%s @ Cycle: %0d", pipeline_msgs[instr_index-1].decode_msgs[i], pipeline_msgs[instr_index-1].decode_cycle);
         $display("|%s @ Cycle: %0d", pipeline_msgs[instr_index-1].execute_msg, pipeline_msgs[instr_index-1].execute_cycle);
         $display("|%s @ Cycle: %0d", pipeline_msgs[instr_index-1].mem_msg, pipeline_msgs[instr_index-1].mem_cycle);
         $display("|%s @ Cycle: %0d", pipeline_msgs[instr_index-1].wb_msg, pipeline_msgs[instr_index-1].wb_cycle);
         $display("==========================================================\n");
      end
    end
  end

endmodule
