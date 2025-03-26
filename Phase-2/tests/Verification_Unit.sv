module Verification_Unit (
  input  logic       clk,
  input  logic       rst,
  // new_instr should be pulsed high for one cycle when a new instruction is fetched.
  input  logic       new_instr,
  // stall and flush signals can be used by your design (if needed) to indicate abnormal conditions.
  input  logic       stall,
  input  logic       flush,
  // String messages provided by each pipeline stage on every cycle.
  input  string      fetch_msg,
  input  string      decode_msg,
  input  string      full_instr_msg, // full instruction text (e.g. "SUB R1, R1, R2")
  input  string      execute_msg,
  input  string      mem_msg,
  input  string      wb_msg
);

  // Define a structure to hold messages for one instruction.
  typedef struct {
    // Use dynamic arrays to store multiple messages if needed.
    string fetch_msgs[$];
    int    fetch_cycle; // We'll use the last cycle when a fetch message was received.
    string decode_msgs[$];
    int    decode_cycle;
    string execute_msg;
    int    execute_cycle;
    string mem_msg;
    int    mem_cycle;
    string wb_msg;
    int    wb_cycle;
    string full_instr; // The complete instruction text.
  } debug_info_t;

  // A dynamic array to hold records for each instruction.
  debug_info_t pipeline_msgs[$];
  // instr_index is the count of instructions processed so far.
  int instr_index;

  // On reset, clear all stored messages.
  always @(posedge clk) begin
    if (rst) begin
      pipeline_msgs.delete();
      instr_index <= 0;
    end else if (new_instr) begin
      // When a new instruction is fetched, push a new record.
      pipeline_msgs.push_back('{
         fetch_msgs: new string[],
         fetch_cycle: 0,
         decode_msgs: new string[],
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

  // On each clock cycle (at posedge), append any stage message (if nonempty)
  // to the current instruction record (the one at index instr_index-1).
  always @(posedge clk) begin
    if (!rst && (instr_index > 0)) begin
      // Append fetch message even during stall cycles.
      if (fetch_msg != "") begin
         pipeline_msgs[instr_index-1].fetch_msgs.push_back(fetch_msg);
         pipeline_msgs[instr_index-1].fetch_cycle = $time / 10;
      end
      // Append decode message.
      if (decode_msg != "") begin
         pipeline_msgs[instr_index-1].decode_msgs.push_back(decode_msg);
         pipeline_msgs[instr_index-1].decode_cycle = $time / 10;
      end
      // Capture execute, memory, and write-back messages (assume one per instruction).
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
         // Now print out the full debug information.
         $display("==========================================================");
         $display("| Instruction: %s | Completed At Cycle: %0d |", 
                  pipeline_msgs[instr_index-1].full_instr, pipeline_msgs[instr_index-1].wb_cycle);
         $display("==========================================================");
         foreach(pipeline_msgs[instr_index-1].fetch_msgs[i])
           $display("|[FETCH] %s @ Cycle: %0d", pipeline_msgs[instr_index-1].fetch_msgs[i], pipeline_msgs[instr_index-1].fetch_cycle);
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
