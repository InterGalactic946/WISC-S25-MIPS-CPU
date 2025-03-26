module Verification_Unit (
  input  logic       clk,
  input  logic       rst,
  // Pulse this high for one cycle when a new instruction is fetched.
  input  logic       new_instr,
  // Stall and flush signals (if needed by your design)
  input  logic       stall,
  input  logic       flush,
  // Stage messages (should be driven only for one cycle when valid)
  input  string      fetch_msg,
  input  string      decode_msg,
  input  string      full_instr_msg, // e.g. "SUB R1, R1, R2"
  input  string      execute_msg,
  input  string      mem_msg,
  input  string      wb_msg
);

  // Structure to hold messages for one instruction.
  typedef struct {
    // Dynamic arrays for stages that can have multiple messages.
    string fetch_msgs[$];
    int    fetch_cycle;    // Use the cycle of the last captured fetch message.
    string decode_msgs[$];
    int    decode_cycle;
    // For execute, memory, and write-back we assume one message each.
    string execute_msg;
    int    execute_cycle;
    string mem_msg;
    int    mem_cycle;
    string wb_msg;
    int    wb_cycle;
    // Full instruction text.
    string full_instr;
  } debug_info_t;

  // Array to store debug records.
  debug_info_t pipeline_msgs[$];
  int instr_index;

  // Internal registers to detect changes (avoid duplicate pushes)
  string last_fetch_msg, last_decode_msg, last_execute_msg, last_mem_msg, last_wb_msg;

  // On reset, clear the debug records.
  always @(posedge clk) begin
    if (rst) begin
      pipeline_msgs.delete();
      instr_index <= 0;
      last_fetch_msg = "";
      last_decode_msg = "";
      last_execute_msg = "";
      last_mem_msg = "";
      last_wb_msg = "";
    end else if (new_instr) begin
      // When a new instruction is fetched, push a new record and capture the full instruction.
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
         full_instr: full_instr_msg
      });
      instr_index++;
      // Reset last-captured messages for the new instruction.
      last_fetch_msg = "";
      last_decode_msg = "";
      last_execute_msg = "";
      last_mem_msg = "";
      last_wb_msg = "";
    end
  end

  // At each clock cycle, check for new messages and update the record for the current instruction.
  always @(posedge clk) begin
    if (!rst && (instr_index > 0)) begin
      // For FETCH stage: if fetch_msg is nonempty and different from the last captured message.
      if ((fetch_msg != "") && (fetch_msg != last_fetch_msg)) begin
         pipeline_msgs[instr_index-1].fetch_msgs.push_back(fetch_msg);
         pipeline_msgs[instr_index-1].fetch_cycle = $time / 10;
         last_fetch_msg = fetch_msg;
      end
      // For DECODE stage:
      if ((decode_msg != "") && (decode_msg != last_decode_msg)) begin
         pipeline_msgs[instr_index-1].decode_msgs.push_back(decode_msg);
         pipeline_msgs[instr_index-1].decode_cycle = $time / 10;
         last_decode_msg = decode_msg;
      end
      // For EXECUTE stage: assume one message pulse.
      if ((execute_msg != "") && (execute_msg != last_execute_msg)) begin
         pipeline_msgs[instr_index-1].execute_msg = execute_msg;
         pipeline_msgs[instr_index-1].execute_cycle = $time / 10;
         last_execute_msg = execute_msg;
      end
      // For MEMORY stage:
      if ((mem_msg != "") && (mem_msg != last_mem_msg)) begin
         pipeline_msgs[instr_index-1].mem_msg = mem_msg;
         pipeline_msgs[instr_index-1].mem_cycle = $time / 10;
         last_mem_msg = mem_msg;
      end
      // For WRITE-BACK stage:
      if ((wb_msg != "") && (wb_msg != last_wb_msg)) begin
         pipeline_msgs[instr_index-1].wb_msg = wb_msg;
         pipeline_msgs[instr_index-1].wb_cycle = $time / 10;
         last_wb_msg = wb_msg;
         // On write-back, print the complete record.
         $display("==========================================================");
         $display("| Instruction: %s | Completed At Cycle: %0d |", 
                  pipeline_msgs[instr_index-1].full_instr, pipeline_msgs[instr_index-1].wb_cycle);
         $display("==========================================================");
         // Print each fetch message.
         foreach(pipeline_msgs[instr_index-1].fetch_msgs[i])
           $display("|[FETCH] %s @ Cycle: %0d", pipeline_msgs[instr_index-1].fetch_msgs[i], pipeline_msgs[instr_index-1].fetch_cycle);
         // Print each decode message.
         foreach(pipeline_msgs[instr_index-1].decode_msgs[i])
           $display("|[DECODE] %s @ Cycle: %0d", pipeline_msgs[instr_index-1].decode_msgs[i], pipeline_msgs[instr_index-1].decode_cycle);
         $display("|[EXECUTE] %s @ Cycle: %0d", pipeline_msgs[instr_index-1].execute_msg, pipeline_msgs[instr_index-1].execute_cycle);
         $display("|[MEMORY] %s @ Cycle: %0d", pipeline_msgs[instr_index-1].mem_msg, pipeline_msgs[instr_index-1].mem_cycle);
         $display("|[WRITE-BACK] %s @ Cycle: %0d", pipeline_msgs[instr_index-1].wb_msg, pipeline_msgs[instr_index-1].wb_cycle);
         $display("==========================================================\n");
      end
    end
  end

endmodule
