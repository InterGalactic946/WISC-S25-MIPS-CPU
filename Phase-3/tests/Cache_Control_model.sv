///////////////////////////////////////////////////////////
// Cache_Control_model.sv                                //
// FSM to handle cache line fills on a cache miss.       //
// It issues memory requests and updates the cache data  //
// and tag arrays once the memory returns valid data.    //
///////////////////////////////////////////////////////////
module Cache_Control_model (
    input  logic        clk, rst,           // Clock signal and active high reset signal
    input  logic        miss_detected,      // High when tag match logic detects a cache miss
    input  logic [15:0] miss_address,       // Address that missed in the cache
    input  logic [15:0] memory_data,        // Data returned by memory after delay
    input  logic        memory_data_valid,  // Active high signal indicating valid data returning on memory bus

    output logic        fsm_busy,           // High while FSM is busy handling the miss (used as a pipeline stall signal)
    output logic        write_data_array,   // Write enable to cache data array to signal when filling with memory_data
    output logic        write_tag_array,    // Write enable to cache tag array when all words are filled in to data array
    output logic [15:0] memory_address,     // Address to read from memory
    output logic [15:0] memory_data_out     // Data to be written to the cache data array
  );

  ///////////////////////////////////////
  // Declare state types as enumerated //
  ///////////////////////////////////////
  typedef enum logic {IDLE, WAIT} state_t;

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  logic clr_count;            // Clear the word count register.
  logic miss_detected_pl;     // Delayed version of the miss_detected signal.
  logic incr_cnt;             // Increment the word count register.
  logic [3:0] new_word_count; // Holds the new word count value.
  logic [3:0] word_count;     // Holds the number of words filled in the cache data array.
  logic [15:0] nxt_mem_addr;  // Holds the next memory address to read from.
  logic [15:0] new_mem_addr;  // Holds the new memory address to read from.
  logic chunks_filled;        // Indicates if the cache data array is filled with all 8 words.
  state_t state;              // Holds the current state.
  state_t nxt_state;          // Holds the next state. 
  logic error;                // Error flag raised when state machine is in an invalid state.  
  ////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////
  // Keep track of the number of words filled in the cache data array //
  /////////////////////////////////////////////////////////////////////
  always_ff @(posedge clk) begin
    if (rst) begin                 
      word_count <= 4'h0;              // Reset the word count to zero.
    end else if (clr_count) begin      // Clear the word count register when we get a cache miss.
      word_count <= 4'h0;              // Reset the word count to zero.
    end else if (incr_cnt) begin       // Increment the word count register when we get valid data from memory.
      word_count <= word_count + 1'b1; // Update the word count with the new value.
    end
  end

  ////////////////////////////////////////////////////
  // Keep track of the address to read from memory //
  //////////////////////////////////////////////////
  always_ff @(posedge clk) begin
    if (rst) begin             
      memory_address <= 16'h0000;                  // Clear the memory address register on reset.
    end else if (clr_count) begin                  // On a cache miss, set the memory address to the miss address.
      memory_address <= {miss_address[15:4], 4'h0};// Set the memory address to the first address of the block.
    end else if (incr_cnt) begin                   // Increment the memory address register when we get valid data from memory.
      memory_address <= memory_address + 16'h0002; // Update the memory address with the new value.
    end
  end

  /////////////////////////////////////
  // Implements State Machine Logic //
  ///////////////////////////////////
  // Implements state machine register, holding current state or next state, accordingly.
  always_ff @(posedge clk) begin
    if(rst)
      state <= IDLE; // Reset into the idle state if machine is reset.
    else
      state <= nxt_state; // Store the next state as the current state by default.
  end

  // We are done filling the cache data array when we have filled all 8 words.
  assign chunks_filled = word_count == 4'h8;
  
  //////////////////////////////////////////////////////////////////////////////////////////
  // Implements the combinational state transition and output logic of the state machine.//
  ////////////////////////////////////////////////////////////////////////////////////////
  always_comb begin
    /* Default all SM outputs & nxt_state */
    nxt_state = state;       // By default, assume we are in the current state.
    clr_count = 1'b0;        // By default, assume we are not clearing the counts.
    fsm_busy = 1'b0;         // By default, assume the FSM is not busy.
    incr_cnt = 1'b0;         // By default, assume we are not incrementing the word count.
    memory_data_out = 16'h0000; // By default, assume we are not writing to memory.
    write_data_array = 1'b0; // By default, assume we are not writing to the cache data array.
    write_tag_array = 1'b0;  // By default, assume we are not writing to the tag array.
    error = 1'b0;            // Default no error state.

    case (state)
      WAIT : begin // WAIT state - waiting for memory data to be valid and all 8 words to be filled in the cache data array.
        fsm_busy = 1'b1; // Assert fsm_busy when waiting for all 8 words to be filled in the cache data array.
        if (chunks_filled) begin // If all 8 words are filled in the cache data array, go to IDLE state.
          nxt_state = IDLE; // Go to IDLE state.
          fsm_busy = 1'b0; // Deassert fsm_busy when the cache data array is filled with all 8 words.
          write_tag_array = 1'b1; // Write to the tag array when all 8 words are filled in the cache data array.
        end else if (memory_data_valid) begin // If memory data is valid, increment the word count and write to the cache data array.
          incr_cnt = 1'b1; // Increment the word count when memory data is valid.
          write_data_array = 1'b1; // Write to the cache data array when memory data is valid.
          memory_data_out = memory_data; // Write the memory data to the cache data array.
        end
      end

      IDLE : begin // IDLE state - waits for a cache miss to occur.
        if (miss_detected) begin
          fsm_busy = 1'b1;  // Assert fsm_busy when a cache miss is detected. 
          clr_count = 1'b1; // Clear the counts and capture the new miss address.
          nxt_state = WAIT; // If a cache miss is detected, go to the WAIT state.
        end
      end

      default : begin // ERROR state - invalid state.
        nxt_state = IDLE;        // Go to IDLE state on error.
        clr_count = 1'b0;        // By default, assume we are not clearing the counts.
        fsm_busy = 1'b0;         // By default, assume the FSM is not busy.
        incr_cnt = 1'b0;         // By default, assume we are not incrementing the word count.
        write_data_array = 1'b0; // By default, assume we are not writing to the cache data array.
        write_tag_array = 1'b0;  // By default, assume we are not writing to the tag array.
        error = 1'b1;            // Default error state.
      end
    endcase
  end

endmodule