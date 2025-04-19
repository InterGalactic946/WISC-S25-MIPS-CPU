///////////////////////////////////////////////////////////
// Cache_Control_model.sv                                //
// FSM to handle cache line fills on a cache miss.       //
// It issues memory requests and updates the cache data  //
// and tag arrays once the memory returns valid data.    //
///////////////////////////////////////////////////////////
module Cache_Control_model (
    input  wire        clk, rst,           // Clock signal and active high reset signal
    input  wire        proceed,            // Signal to proceed with memory filling on a cache miss
    input  wire        miss_detected,      // High when tag match logic detects a cache miss from previous cycle         
    input  wire [15:0] miss_address,       // Address that missed in the cache
    input  wire [15:0] memory_data,        // Data returned by memory after delay
    input  wire        memory_data_valid,  // Active high signal indicating valid data returning on memory bus
    input  wire        first_tag_LRU,      // Pipelined first line tag's LRU from the cache
    input  wire        first_match,        // Pipelined match signal for the first line of the cache set

    output reg        fsm_busy,            // High while FSM is busy handling the miss (used as a pipeline stall signal)
    
    output wire [7:0] TagIn,               // Output tag to rewrite upon a miss
    output reg        write_tag_array,     // Write enable to cache tag array when all words are filled in to data array
    output wire       Set_First_LRU,       // Sets the first LRU bit and clears the second
    output wire       evict_first_way,     // Indicates which line we are evicting on a cache miss

    output reg        write_data_array,    // Write enable to cache data array to signal when filling with memory_data

    output wire [15:0] memory_address,     // Address to read from memory
    output reg [15:0] memory_data_out      // Data to be written to memory
  );
  
  ///////////////////////////////////////
  // Declare state types as enumerated //
  ///////////////////////////////////////
  typedef enum logic {IDLE, WAIT} state_t;

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire hit;                  // High when cache hit is detected from the previous cycle    
  reg clr_count;             // Clear the word count register.
  reg incr_cnt;              // Increment the word count register.
  wire [3:0] new_word_count; // Holds the new word count value.
  wire [3:0] nxt_word_count; // Holds the next word count value.
  wire [3:0] word_count;     // Holds the number of words filled in the cache data array.
  wire [15:0] nxt_mem_addr;  // Holds the next memory address to read from.
  wire [15:0] new_mem_addr;  // Holds the new memory address to read from.
  wire chunks_filled;        // Indicates if the cache data array is filled with all 8 words.
  wire state;                // Holds the current state.
  reg nxt_state;             // Holds the next state. 
  reg error;                 // Error flag raised when state machine is in an invalid state.  
  ////////////////////////////////////////////////

  // Indicates it is a hit if not a miss.
  assign hit = ~miss_detected;

  // If the second cache line's LRU is 1, evict second_way (1), else evict first_way (0). (TagOut[0] == LRU)
  assign evict_first_way = first_tag_LRU;

  // If we have a cache hit and the first line is a match, then we clear the first line's LRU bit. Otherwise, if the second line is a match
  // on a hit, then we set the set the first line's LRU bit. If there is a cache miss and we are evicting the first way, then we clear the
  // first cache line's LRU bit and set the second's, Otherwise, if the second way is evicted on a miss, then we set the first line's LRU bit 
  // and clear the second line's.
  // (((first_match) ? 1'b0 : 1'b1)) : (((evict_first_way) ? 1'b0 : 1'b1));
  assign Set_First_LRU = (hit) ? ~first_match : ~evict_first_way;

  //////////// Tag to write to the cache after we have detected a miss ////////////
  // On a cache hit on the first way, we update the tag with the new incoming tag, valid bit set, and LRU bit unset. Else if it did not hit on the first way, we set its LRU bit,
  // and keeping the content the same. Otherwise, if it is a cache miss, and we must evict the first "way", we update it with the new tag along with LRU bit unset. If
  // we don't have to evict the first "way", we set its LRU bit as the the second "way" that is evicted is now most recently used.
  assign TagIn = {miss_address[15:10], 1'b1, 1'b0};

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
          fsm_busy = 1'b1;    // Assert fsm_busy when a cache miss is detected. 
          clr_count = 1'b1;   // Clear the counts and capture the new miss address.
          
          if (proceed)
            nxt_state = WAIT;   // If a cache miss is detected, go to the WAIT state only if allowed to proceed else stay in IDLE.
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