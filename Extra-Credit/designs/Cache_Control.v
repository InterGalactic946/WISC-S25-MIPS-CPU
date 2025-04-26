`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////
// Cache_Control.v                                       //
// FSM to handle cache line fills on a cache miss.       //
// It issues memory requests and updates the cache data  //
// and tag arrays once the memory returns valid data.    //
///////////////////////////////////////////////////////////
module Cache_Control (
    input  wire        clk, rst,           // Clock signal and active high reset signal
    input  wire        proceed,            // Signal to proceed with memory filling on a cache miss
    input  wire        miss_detected,      // High when tag match logic detects a cache miss         
    input  wire [15:0] miss_address,       // Address that missed in the cache
    input  wire        memory_data_valid,  // Active high signal indicating valid data returning on memory bus

    output wire        fsm_busy,           // High while FSM is busy handling the miss
    output wire         mem_en,            // Signal to enable main memory on a miss
    
    output wire [7:0] tag_out,             // Output tag to rewrite upon a miss
    output wire        write_tag_array,     // Write enable to cache tag array when all words are filled in to data array

    output reg        write_data_array,     // Write enable to cache data array to signal when filling with memory_data

    output wire [15:0] main_memory_address,  // Address to read from memory
    output wire [15:0] cache_memory_address  // Address to write to cache
  );
  
  ////////////////////////////////////////
  // Declare state types as parameters //
  //////////////////////////////////////  
  parameter IDLE = 2'h0;   // IDLE state - waiting for a cache miss to occur.
  parameter WAIT = 2'h1;   // WAIT state - waiting for memory data to be valid.
  parameter SEND = 2'h2;   // SEND state - waiting for memory data to be valid.

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  /********** Delayed/Pipelined memory addresses ********/
  wire [15:0] memory_address_3; 
  wire [15:0] memory_address_2;
  wire [15:0] memory_address_1;
  wire [15:0] new_mem3_addr, new_mem2_addr, new_mem1_addr, new_cache_addr;
  /*****************************************************/
  reg clr_count;             // Clear the word count register.
  reg incr_cnt;              // Increment the word count register.
  wire [7:0] new_tag_out;    // The new state of the tag register.
  wire [3:0] new_valid_count; // Holds the new valid count value.
  wire [3:0] nxt_valid_count; // Holds the next valid count value.
  wire [3:0] valid_count;    // Holds the number of times we received a valid signal.
  wire [15:0] nxt_mem_addr;  // Holds the next memory address to read from.
  wire [15:0] new_mem_addr;  // Holds the new memory address to read from.
  wire chunks_filled;        // Indicates if the cache data array is filled with all 8 words.
  wire chunk7;               // Indicates if the cache data array is filled with 7 words.
  wire eight_cycles;           // Indicates if we sent out the enable signal for 6 cycles.
  reg set_fsm_busy;          // Indicates we need to stall.
  reg set_mem_en;            // Indicates we enable main memory on a miss.
  reg clr_mem_en;            // Clears the signal after 6 cycles.
  reg clr_fsm_busy;          // Clears the signal after processing the miss.
  wire new_mem_en;           // The new mem enable signal.
  wire new_fsm_busy;         // The new fsm_busy signal.
  wire [1:0] state;          // Holds the current state.
  reg [1:0] nxt_state;       // Holds the next state. 
  reg error;                 // Error flag raised when state machine is in an invalid state.  
  ////////////////////////////////////////////////

  // On a cache hit on the first way, we update the tag with the new incoming tag, valid bit set, and LRU bit unset. Else if it did not hit on the first way, we set its LRU bit,
  // and keeping the content the same. Otherwise, if it is a cache miss, and we must evict the first "way", we update it with the new tag along with LRU bit unset. If
  // we don't have to evict the first "way", we set its LRU bit as the the second "way" that is evicted is now most recently used.
  assign new_tag_out = (clr_count) ? {miss_address[15:10], 1'b1, 1'b0} : tag_out;
  
  // Keep track of the tag to set on a miss.
  CPU_Register #(.WIDTH(8)) iTAG_OUT_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(new_tag_out), .data_out(tag_out));
  
  /////////////////////////////////////////////////////////////////////
  // Keep track of the number of times we received the valid signal //
  ///////////////////////////////////////////////////////////////////
  // We increment the valid count register once we get valid data from memory.
  CLA_4bit iVALID_COUNT (.A(valid_count), .B(4'h1), .sub(1'b0), .Cin(1'b0), .Sum(nxt_valid_count), .Cout(), .Ovfl());

  // We clear the valid count register when we get a cache miss and increment on the valid signal only when allowed to proceed.
  assign new_valid_count = (clr_count) ? 4'h0 : ((memory_data_valid & proceed) ? nxt_valid_count : valid_count);

  // Get a counter to keep track of the number of words filled in the cache data array.
  CPU_Register #(.WIDTH(4)) iVALID_COUNT_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(new_valid_count), .data_out(valid_count));

  ////////////////////////////////////////////////////
  // Keep track of the address to read from memory //
  //////////////////////////////////////////////////
  // We increment the memory address by 2 for each word filled in the cache data array.
  CLA_16bit iMEM_NEXT (.A(main_memory_address), .B(16'h0002), .sub(1'b0), .Sum(nxt_mem_addr), .Cout(), .Ovfl(), .pos_Ovfl(), .neg_Ovfl());

  // We set the new memory address to the first address of the block when we get a cache miss otherwise we increment the address by 2 for each word filled in the cache data array.
  assign new_mem_addr = (clr_count) ? {miss_address[15:4], 4'h0} : ((incr_cnt) ? nxt_mem_addr : main_memory_address);

  // Keep track of the memory address to read from.
  CPU_Register iMEM_ADDR_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(new_mem_addr), .data_out(main_memory_address));

  // On the first cycle of the miss, reset it to the miss address.
  assign new_mem3_addr = (clr_count) ? {miss_address[15:4], 4'h0} : main_memory_address;

  // Keep track of the first delayed memory address.
  CPU_Register iMEM_ADDR_REG_3 (.clk(clk), .rst(rst), .wen(1'b1), .data_in(new_mem3_addr), .data_out(memory_address_3));

  // On the first cycle of the miss, reset it to the miss address.
  assign new_mem2_addr = (clr_count) ? {miss_address[15:4], 4'h0} : memory_address_3;

  // Keep track of the second delayed memory address.
  CPU_Register iMEM_ADDR_REG_2 (.clk(clk), .rst(rst), .wen(1'b1), .data_in(new_mem2_addr), .data_out(memory_address_2));

  // On the first cycle of the miss, reset it to the miss address.
  assign new_mem1_addr = (clr_count) ? {miss_address[15:4], 4'h0} : memory_address_2;
  
  // Keep track of the third delayed memory address.
  CPU_Register iMEM_ADDR_REG_1 (.clk(clk), .rst(rst), .wen(1'b1), .data_in(new_mem1_addr), .data_out(memory_address_1));

  // On the first cycle of the miss, reset it to the miss address.
  assign new_cache_addr = (clr_count) ? {miss_address[15:4], 4'h0} : memory_address_1;
  
  // Keep track of the address to write to in the cache.
  CPU_Register iCACHE_ADDR_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(new_cache_addr), .data_out(cache_memory_address));
  ///////////////////////////////////////////////////

  /////////////////////////////////////
  // Implements State Machine Logic //
  ///////////////////////////////////
  // Implements state machine register, holding current state or next state, accordingly.
  CPU_Register #(.WIDTH(2)) iSTATE_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(nxt_state), .data_out(state));

  // Sets the fsm_busy signal to assert stall to the processor.
  assign new_fsm_busy = (set_fsm_busy) ? 1'b1 : ((clr_fsm_busy) ? 1'b0 : fsm_busy);

  // Used as an SR flop to set the busy signal.
  CPU_Register #(.WIDTH(1)) iFSM_BUSY_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(new_fsm_busy), .data_out(fsm_busy));

  // Sets the memory enable signal to begin processing the miss.
  assign new_mem_en = (set_mem_en) ? 1'b1 : ((clr_mem_en) ? 1'b0 : mem_en);

  // Used as an SR flop to enable main memory.
  CPU_Register #(.WIDTH(1)) iMEM_EN_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(new_mem_en), .data_out(mem_en));

  // We are done setting the memory enable for 6 cycles when the LSBs of main memory address is 0xE.
  assign eight_cycles = main_memory_address[3:0] == 4'hE;

  // We are done filling 7 words in the cache.
  assign chunk7 = valid_count == 4'h7;

  // We are done filling the cache data array when we have filled all 8 words.
  assign chunks_filled = valid_count == 4'h8;
  ////////////////////////////////////

  assign write_tag_array = state[1] & chunk7 & memory_data_valid;
  
  //////////////////////////////////////////////////////////////////////////////////////////
  // Implements the combinational state transition and output logic of the state machine.//
  ////////////////////////////////////////////////////////////////////////////////////////
  always @(*) begin
    /* Default all SM outputs & nxt_state */
    nxt_state = state;       // By default, assume we are in the current state.
    set_mem_en = 1'b0;       // By default assume we are not enabling main memory.
    clr_fsm_busy = 1'b0;     // By default, assume we are not clearing the signal.
    clr_mem_en = 1'b0;       // By default, assume we are not clearing the signal.
    clr_count = 1'b0;        // By default, assume we are not clearing the counts.
    set_fsm_busy = 1'b0;     // By default, assume the FSM is not busy.
    incr_cnt = 1'b0;         // By default, assume we are not incrementing the word count.
    write_data_array = 1'b0; // By default, assume we are not writing to the cache data array.
    // write_tag_array = 1'b0;  // By default, assume we are not writing to the tag array.
    error = 1'b0;            // Default no error state.

    case (state)
      SEND : begin // SEND state - Fill the cache from main memory data
        incr_cnt = 1'b1; // Increment every cycle to send out a new address.
        write_data_array = (memory_data_valid & ~chunks_filled); // Write to the cache data array when memory data is valid or all 8 words are filled.
        clr_fsm_busy = memory_data_valid & chunk7;    // Clear the busy and enab;e signals when the cache data array is filled with all 8 words.
        clr_mem_en = eight_cycles;                    // Clear it after 8 cycles
        // write_tag_array = memory_data_valid & chunk7; // Write to the tag array when 7 words are filled in the cache data array and we get one more valid signal.
        nxt_state = ~(chunks_filled) ? SEND : IDLE;   // Go back to IDLE state if all 8 words are filled in the cache data array.
      end

      WAIT : begin  // WAIT state - waiting for grant to proceed to access memory.
        set_mem_en = proceed;                // Enable main memory when allowed to proceed.
        nxt_state = (proceed) ? SEND : WAIT; // Go to the send state once allowed to proceed.
      end

      IDLE : begin // IDLE state - waits for a cache miss to occur.
        set_fsm_busy = (miss_detected);               // Assert fsm_busy when a cache miss is detected.
        clr_count = (miss_detected);                  // Clear the counts and capture the new miss address.
        nxt_state = (miss_detected) ? WAIT : IDLE;    // Go to the WAIT state to wait for memory access on a cache miss.
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
        // write_tag_array = 1'b0;  // By default, assume we are not writing to the tag array.
        error = 1'b1;            // Default error state.
      end
    endcase
  end

endmodule

`default_nettype wire // Reset default behavior at the end