  ///////////////////////////////////////////////////////////
// Verification_Unit.sv: Verification Unit Module        //  
//                                                       //
// This module is responsible for verifying and          //
// displaying debug messages for each instruction in     //
// the CPU pipeline stages. It tracks the instruction's  //
// journey through the fetch, decode, execute, memory,   //
// and write-back stages. The module also stores debug   //
// messages at each stage and prints the full pipeline   //
// information when the instruction reaches the          //
// write-back stage. This helps in debugging and         //
// ensuring correct operation of the CPU's pipeline.     //
///////////////////////////////////////////////////////////  
  module PrintingUnit (
      input logic clk, rst_n,
      input string fetch_msg,
      input string decode_msg,
      input string instruction_full_msg,
      input string execute_msg,
      input string mem_msg,
      input string wb_msg,
      input logic stall
  );

  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  // Define pipeline stages (states).
  typedef enum logic [2:0] {EMPTY, FETCH, DECODE, EXECUTE, MEMORY, WRITEBACK} state_t;

  // Define struct for instruction tracking
  typedef struct {
    state_t stage;
    string fetch_msgs[0:4], decode_msgs[0:4], instr_full_msg, execute_msg, memory_msg, wb_msg;
    logic print;
  } instr_t;

  instr_t pipeline[0:4];    // Pipeline: 1D array to track each instruction's stage
  logic [2:0] curr_num_instrns;    // Number of instructions currently in the pipeline
  state_t nxt_stages[0:4];   // Holds the next state
  string fetch_msgs[0:4][0:4], decode_msgs[0:4][0:4]; // Message arrays for each instruction
  string execute_msgs[0:4], memory_msgs[0:4], wb_msgs[0:4]; // Execution messages
  string instr_full_msgs[0:4];
  logic print_flags[0:4];    // Holds the print flags
  logic shift;

  // Implement counter to keep track of current number of instructions in pipeline.
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      curr_num_instrns <= 3'h1;                      // Reset the curr_num_instrns value.
    else if (shift)
      curr_num_instrns <= curr_num_instrns - 1'b1;   // Decrement the number of instructions in the pipeline
    else if (!stall && curr_num_instrns < MAX_INSTRS)
      curr_num_instrns <= curr_num_instrns + 1'b1;   // Increment the curr_num_instrns.
  end


  // Simulate pipeline execution
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n)
      msg_index <= 3'h0;
    else if (!stall)
      msg_index <= 3'h0;
    else if (stall)
      msg_index <= (msg_index + 1'b1) % 5;
  end

  /////////////////////////////////////
  // Implements State Machine Logic //
  ///////////////////////////////////
  // Implements state machine register, holding current state or next state, accordingly.
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        // Reset all instructions to EMPTY state
        for (int i = 0; i < 5; i++) begin
            if (i === 0)
              pipeline[i] <= '{FETCH, '{default: ""}, '{default: ""}, "", "", "", "", 0};
            else
              pipeline[i] <= '{EMPTY, '{default: ""}, '{default: ""}, "", "", "", "", 0};
        end
    end else begin
        // Update the pipeline based on parallel arrays.
        for (int i = 0; i < curr_num_instrns; i++) begin
            pipeline[i].stage <= nxt_stages[i];
            pipeline[i].print <= print_flags[i];
            pipeline[i].fetch_msgs <= fetch_msgs[i];
            pipeline[i].decode_msgs <= decode_msgs[i];
            pipeline[i].instr_full_msg <= instr_full_msgs[i];
            pipeline[i].execute_msg <= execute_msgs[i];
            pipeline[i].memory_msg <= memory_msgs[i];
            pipeline[i].wb_msg <= wb_msgs[i];
        end

        if (shift) begin // Shift in new instructions into the pipeline.
          for (int i = 0; i < curr_num_instrns + 1; i++) begin
              pipeline[i] <= pipeline[i+1];
          end

          // Insert new instruction at the last index (curr_num_instrns points to this)
          pipeline[curr_num_instrns] <= '{FETCH, '{default: ""}, '{default: ""}, "", "", "", "", 0};

        end
    end
  end


  // Simulate pipeline execution
  always_ff @(posedge clk) begin
        // Print the pipeline status for each cycle and capture messages
        for (int i = 0; i < curr_num_instrns; i++) begin
            if (pipeline[i].print) begin
                $display("==========================================================");
                $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline[i].instr_full_msg, $time / 10);
                $display("==========================================================");
                
                for (int j = 0; j < 5; j = j+1)
                    if (pipeline[i].fetch_msgs[j] !== "")
                        $display("%s", pipeline[i].fetch_msgs[j]);
               
                for (int j = 0; j < 5; j = j+1)
                    if (pipeline[i].decode_msgs[j] !== "")
                        $display("%s", pipeline[i].decode_msgs[j]);

                $display("%s", pipeline[i].execute_msg);
                $display("%s", pipeline[i].memory_msg);
                $display("%s", pipeline[i].wb_msg);
                $display("==========================================================\n");
            end
        end
  end
  
  //////////////////////////////////////////////////////////////////////////////////////////
  // Implements the combinational state transition and output logic of the state machine. //
  ////////////////////////////////////////////////////////////////////////////////////////
  always_comb begin
      // Default state transitions and messages for each instruction
      for (int i = 0; i < curr_num_instrns; i++) begin
          nxt_stages[i] = pipeline[i].stage;   // Default to current state
          print_flags[i] = 1'b0;               // Default to no print
          fetch_msgs[i] = '{default: ""};      // Default messages to "" for all states
          decode_msgs[i] = '{default: ""};
          instr_full_msgs[i] = "";
          execute_msgs[i] = "";
          memory_msgs[i] = "";
          wb_msgs[i] = "";

          case (pipeline[i].stage)
              FETCH: begin
                  if (!stall)
                      nxt_stages[i] = DECODE;

                  // Keep the fetch message and default others
                  fetch_msgs[i][msg_index] = fetch_msg;
              end

              DECODE: begin
                  if (!stall)
                      nxt_stages[i] = EXECUTE;

                  // Keep the previous fetch message, clear the others
                  decode_msgs[i][msg_index] = decode_msg;

                  instr_full_msgs[i] = instruction_full_msg;

                  // Keep the fetch message from previous stage
                  fetch_msgs[i] = fetch_msgs[i];
              end

              EXECUTE: begin
                  nxt_stages[i] = MEMORY;
                  // Keep the decode message and default others
                  execute_msgs[i] = execute_msg;
                  
                  instr_full_msgs[i] = instr_full_msgs[i];
                  
                  decode_msgs[i] = decode_msgs[i] // Preserve the decode message
                  // Keep the fetch message from previous stage
                  fetch_msgs[i] = fetch_msgs[i];
              end

              MEMORY: begin
                  nxt_stages[i] = WRITEBACK;
                  // Keep execute and decode messages from previous stages
                  memory_msgs[i] = memory_msg;
                  execute_msgs[i] = execute_msgs[i]; // Keep execute message
                  decode_msgs[i] = decode_msgs[i] // Preserve the decode message
                  // Keep the fetch message from previous stage
                  fetch_msgs[i] = fetch_msgs[i];
              end

              WRITEBACK: begin
                  nxt_stages[i] = FETCH;
                  wb_msgs[i] = wb_msg;
                  print_flags[i] = 1'b1; // Indicate to print
                  // Keep memory, execute, decode, and fetch messages
                  memory_msgs[i] = memory_msgs[i]; // Keep memory message
                  execute_msgs[i] = execute_msgs[i]; // Keep execute message
                  decode_msgs[i] = decode_msgs[i] // Preserve the decode message
                  // Keep the fetch message from previous stage
                  fetch_msgs[i] = fetch_msgs[i];

                  shift = 1'b1; // Assert shift to shift in new instructions into the pipeline.
              end

              default: begin
                  if (!stall)
                    nxt_stages[i] = FETCH;
              end
          endcase
      end
  end

endmodule



