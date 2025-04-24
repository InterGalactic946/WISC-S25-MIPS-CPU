///////////////////////////////////////////////////////////
// Cache_Control_model.sv                                //
// FSM to handle cache line fills on a cache miss.       //
// It issues memory requests and updates the cache data  //
// and tag arrays once the memory returns valid data.    //
///////////////////////////////////////////////////////////
module Cache_Control_model (
    input  logic        clk, rst,           // Clock signal and active high reset signal
    input  logic        proceed,            // Signal to proceed with memory filling on a cache miss
    input  logic        miss_detected,      // High when tag match logic detects a cache miss from previous cycle         
    input  logic [15:0] miss_address,       // Address that missed in the cache
    input  logic        memory_data_valid,  // Active high signal indicating valid data returning on memory bus

    output logic        fsm_busy,           // High while FSM is busy handling the miss (used as a pipeline stall signal)
    output logic        mem_en,             // Signal to enable main memory on a miss
    
    output logic [7:0] tag_out,             // Output tag to rewrite upon a miss
    output logic        write_tag_array,    // Write enable to cache tag array when all words are filled in to data array

    output logic        write_data_array,   // Write enable to cache data array to signal when filling with memory_data

    output logic [15:0] main_memory_address,  // Address to read from memory
    output logic [15:0] cache_memory_address // Address to write to cache
  );
  
  ///////////////////////////////////////
  // Declare state types as enumerated //
  ///////////////////////////////////////
  typedef enum logic [1:0] {IDLE, WAIT, SEND} state_t;

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  /********** Delayed/Pipelined memory addresses ********/
  logic [15:0] memory_address_3; 
  logic [15:0] memory_address_2;
  logic [15:0] memory_address_1;
  /*****************************************************/
  logic clr_count;           // Clear the word count register.
  logic incr_cnt;            // Increment the word count register.
  logic [3:0] valid_count;   // Holds the number of words filled in the cache data array.
  logic chunks_filled;       // Indicates if the cache data array is filled with all 8 words.
  logic chunk7;              // Indicates if the cache data array is filled with 7 words.
  logic eight_cycles;        // Indicates if we sent out the enable signal for 6 cycles.
  logic set_fsm_busy;        // Indicates we need to stall.
  logic set_mem_en;          // Indicates we enable main memory on a miss.
  logic clr_mem_en;          // Clears the signal after 6 cycles.
  logic clr_fsm_busy;         // Clears the signal after processing the miss.
  state_t state;             // Holds the current state.
  state_t nxt_state;         // Holds the next state. 
  logic error;               // Error flag raised when state machine is in an invalid state.  
  ////////////////////////////////////////////////

  // On a cache hit on the first way, we update the tag with the new incoming tag, valid bit set, and LRU bit unset. Else if it did not hit on the first way, we set its LRU bit,
  // and keeping the content the same. Otherwise, if it is a cache miss, and we must evict the first "way", we update it with the new tag along with LRU bit unset. If
  // we don't have to evict the first "way", we set its LRU bit as the the second "way" that is evicted is now most recently used.
  always_ff @(posedge clk) begin
    if (rst) begin                 
      tag_out <= 8'h00;                             // Reset the tag out to zero.
    end else if (clr_count) begin                   // Clear the tag out register when we get a cache miss.
      tag_out <= {miss_address[15:10], 1'b1, 1'b0}; // Reset the valid count to zero.
    end
  end

  ///////////////////////////////////////////////////////////////////////
  // Keep track of the number of words filled in the cache data array //
  /////////////////////////////////////////////////////////////////////
  always_ff @(posedge clk) begin
    if (rst) begin                 
      valid_count <= 4'h0;                // Reset the valid count to zero.
    end else if (clr_count) begin         // Clear the valid count register when we get a cache miss.
      valid_count <= 4'h0;                // Reset the valid count to zero.
    end else if (memory_data_valid & proceed) begin // Increment the valid count register when we get valid data from memory and allowed to proceed.
      valid_count <= valid_count + 1'b1;  // Update the valid count with the new value.
    end
  end

  ////////////////////////////////////////////////////
  // Keep track of the address to read from memory //
  //////////////////////////////////////////////////
  always_ff @(posedge clk) begin
    if (rst) begin             
      main_memory_address <= 16'h0000;                       // Clear the memory address register on reset.
    end else if (clr_count) begin                            // On a cache miss, set the memory address to the miss address.
      main_memory_address <= {miss_address[15:4], 4'h0};     // Set the memory address to the first address of the block.
    end else if (incr_cnt) begin                             // Increment the memory address register when we get valid data from memory.
      main_memory_address <= main_memory_address + 16'h0002; // Update the memory address with the new value.
    end
  end

  //////////////////////////////////////////////////////
  // Pipeline the miss address to write to the cache //
  ////////////////////////////////////////////////////
  always_ff @(posedge clk) begin
    if (rst) begin             
      memory_address_3 <= 16'h0000;          // Clear the memory address 3 register on reset.
      memory_address_2 <= 16'h0000;          // Clear the memory address 2 register on reset.
      memory_address_1 <= 16'h0000;          // Clear the memory address 1 register on reset.
      cache_memory_address <= 16'h0000;      // Clear the cache memory address register on reset.
    end else begin
      memory_address_3 <= (clr_count) ? {miss_address[15:4], 4'h0} : main_memory_address; 
      memory_address_2 <= (clr_count) ? {miss_address[15:4], 4'h0} :  memory_address_3;
      memory_address_1 <= (clr_count) ? {miss_address[15:4], 4'h0} :  memory_address_2;
      cache_memory_address <= (clr_count) ? {miss_address[15:4], 4'h0} :  memory_address_1; // This is the address we write to in the cache once we get the valid signal.
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

  // Used as an SR flop to set the busy signal.
  always_ff @(posedge clk) begin
    if(rst)
      fsm_busy <= 1'b0; 
    else if (set_fsm_busy)
      fsm_busy <= 1'b1;
    else if (clr_fsm_busy)
      fsm_busy <= 1'b0;
  end

  // Used as an SR flop to set the memory enable signal.
  always_ff @(posedge clk) begin
    if(rst)
      mem_en <= 1'b0; 
    else if (set_mem_en)
      mem_en <= 1'b1;
    else if (clr_mem_en)
      mem_en <= 1'b0;
  end

  // We are done setting the memory enable for 6 cycles when the LSBs of main memory address is 0xE.
  assign eight_cycles = main_memory_address[3:0] == 4'hE;

  // We are done filling 7 words in the cache.
  assign chunk7 = valid_count == 4'h7;

  // We are done filling the cache data array when we have filled all 8 words.
  assign chunks_filled = valid_count == 4'h8;
  ////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////
  // Implements the combinational state transition and output logic of the state machine.//
  ////////////////////////////////////////////////////////////////////////////////////////
  always_comb begin
    /* Default all SM outputs & nxt_state */
    nxt_state = state;       // By default, assume we are in the current state.
    set_mem_en = 1'b0;       // By default assume we are not enabling main memory.
    clr_fsm_busy = 1'b0;     // By default, assume we are not clearing the signal.
    clr_mem_en = 1'b0;       // By default, assume we are not clearing the signal.
    clr_count = 1'b0;        // By default, assume we are not clearing the counts.
    set_fsm_busy = 1'b0;     // By default, assume the FSM is not busy.
    incr_cnt = 1'b0;         // By default, assume we are not incrementing the word count.
    write_data_array = 1'b0; // By default, assume we are not writing to the cache data array.
    write_tag_array = 1'b0;  // By default, assume we are not writing to the tag array.
    error = 1'b0;            // Default no error state.

    case (state)
      SEND : begin // SEND state - Fill the cache from main memory data
        incr_cnt = 1'b1; // Increment every cycle to send out a new address.
        if (chunks_filled) begin // If all 8 words are filled in the cache data array, go to IDLE state. (8 memory_data_valid pulses)
          nxt_state = IDLE; // Go to IDLE state.
        end else if (memory_data_valid) begin // If memory data is valid, increment the word count and write to the cache data array.
          if (chunk7) begin 
            write_tag_array = 1'b1;  // Write to the tag array when all 8 words are filled in the cache data array.
            clr_fsm_busy = 1'b1;     // Clear the fsm busy signal.
          end
          write_data_array = 1'b1;   // Write to the cache data array when memory data is valid.
        end

        // If 8 cycles have passed, clear the memory enable signal.
        if (eight_cycles)
          clr_mem_en = 1'b1;
      end

      WAIT : begin  // WAIT state - waiting for grant to proceed to access memory.
        if (proceed) begin
          set_mem_en = 1'b1;  // Enable main memory when allowed to proceed.
          nxt_state = SEND;   // Go to the send state once allowed to proceed.
        end
      end

      IDLE : begin // IDLE state - waits for a cache miss to occur.
        if (miss_detected) begin
          set_fsm_busy = 1'b1;   // Set the fsm_busy signal when a cache miss is detected. 
          clr_count = 1'b1;      // Clear the counts and capture the new miss address.
          nxt_state = WAIT;      // If a cache miss is detected, go to the WAIT state to wait for memory grant.
        end
      end

      default : begin // ERROR state - invalid state.
        nxt_state = IDLE;        // Go to IDLE state on error.
        set_mem_en = 1'b0;       // By default assume we are not enabling main memory.
        clr_fsm_busy = 1'b0;     // By default, assume we are not clearing the signal.
        clr_mem_en = 1'b0;       // By default, assume we are not clearing the signal.
        clr_count = 1'b0;        // By default, assume we are not clearing the counts.
        set_fsm_busy = 1'b0;     // By default, assume the FSM is not busy.
        incr_cnt = 1'b0;         // By default, assume we are not incrementing the word count.
        write_data_array = 1'b0; // By default, assume we are not writing to the cache data array.
        write_tag_array = 1'b0;  // By default, assume we are not writing to the tag array.
        error = 1'b1;            // Default error state.
      end
    endcase
  end

endmodule