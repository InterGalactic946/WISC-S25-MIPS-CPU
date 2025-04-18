`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////
// Cache_Control.v                                       //
// FSM to handle cache line fills on a cache miss.       //
// It issues memory requests and updates the cache data  //
// and tag arrays once the memory returns valid data.    //
///////////////////////////////////////////////////////////
module Cache_Control (
    input  wire        clk, rst,           // Clock signal and active high reset signal
    input  wire        miss_detected,      // High when tag match logic detects a cache miss
    input  wire [15:0] miss_address,       // Address that missed in the cache
    input  wire [15:0] memory_data,        // Data returned by memory after delay
    input  wire        memory_data_valid,  // Active high signal indicating valid data returning on memory bus

    output reg        fsm_busy,            // High while FSM is busy handling the miss (used as a pipeline stall signal)
    output reg        write_data_array,    // Write enable to cache data array to signal when filling with memory_data
    output reg        write_tag_array,     // Write enable to cache tag array when all words are filled in to data array
    output wire [15:0] memory_address,     // Address to read from memory
    output reg [15:0] memory_data_out      // Data to be written to memory
  );

  ////////////////////////////////////////
  // Declare state types as parameters //
  //////////////////////////////////////  
  parameter IDLE = 1'b0; // IDLE state - waiting for a cache miss to occur.
  parameter WAIT = 1'b1; // WAIT state - waiting for memory data to be valid.

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire miss_detected_pl;     // Pipelined version of the miss_detected signal.
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

  ///////////////////////////////////////////////////////////////////////
  // Keep track of the number of words filled in the cache data array //
  /////////////////////////////////////////////////////////////////////
  // We increment the word count register once we get valid data from memory.
  CLA_4bit iWORD_COUNT (.A(word_count), .B(4'h1), .sub(1'b0), .Cin(1'b0), .Sum(nxt_word_count), .Cout(), .Ovfl());

  // We clear the word count register when we get a cache miss.
  assign new_word_count = (clr_count) ? 4'h0 : ((incr_cnt) ? nxt_word_count : word_count);

  // Get a counter to keep track of the number of words filled in the cache data array.
  CPU_Register #(.WIDTH(4)) iWORD_COUNT_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(new_word_count), .data_out(word_count));

  ////////////////////////////////////////////////////
  // Keep track of the address to read from memory //
  //////////////////////////////////////////////////
  // We increment the memory address by 2 for each word filled in the cache data array.
  CLA_16bit iMEM_NEXT (.A(memory_address), .B(16'h0002), .sub(1'b0), .Sum(nxt_mem_addr), .Cout(), .Ovfl(), .pos_Ovfl(), .neg_Ovfl());

  // We set the new memory address to the first address of the block when we get a cache miss otherwise we increment the address by 2 for each word filled in the cache data array.
  assign new_mem_addr = (clr_count) ? {miss_address[15:4], 4'h0} : ((incr_cnt) ? nxt_mem_addr : memory_address);

  // Keep track of the memory address to read from.
  CPU_Register iMEM_ADDR_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(new_mem_addr), .data_out(memory_address));

  /////////////////////////////////////
  // Implements State Machine Logic //
  ///////////////////////////////////
  // Implements state machine register, holding current state or next state, accordingly.
  CPU_Register #(.WIDTH(1)) iSTATE_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(nxt_state), .data_out(state));

  // We are done filling the cache data array when we have filled all 8 words.
  assign chunks_filled = word_count == 4'h8;
  
  //////////////////////////////////////////////////////////////////////////////////////////
  // Implements the combinational state transition and output logic of the state machine.//
  ////////////////////////////////////////////////////////////////////////////////////////
  always @(*) begin
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
        write_data_array = (memory_data_valid & ~chunks_filled) ? 1'b1 : 1'b0; // Write to the cache data array when memory data is valid and not all 8 words are filled.
        incr_cnt = (memory_data_valid & ~chunks_filled) ? 1'b1 : 1'b0;         // Increment the word count when memory data is valid and not all 8 words are filled.
        memory_data_out = (memory_data_valid & ~chunks_filled) ? memory_data : 16'h0000; // Write the memory data to the cache data array when memory data is valid and not all 8 words are filled.
        fsm_busy = (chunks_filled) ? 1'b0 : 1'b1;                              // Assert fsm_busy when the cache data array is not filled with all 8 words.
        write_tag_array = (chunks_filled) ? 1'b1 : 1'b0;                       // Write to the tag array when all 8 words are filled in the cache data array.
        nxt_state = (chunks_filled) ? IDLE : WAIT;                             // Go back to IDLE state if all 8 words are filled in the cache data array.
      end

      IDLE : begin // IDLE state - waits for a cache miss to occur.
        fsm_busy =  (miss_detected) ? 1'b1 : 1'b0;  // Assert fsm_busy when a cache miss is detected.
        clr_count = (miss_detected) ? 1'b1 : 1'b0;  // Clear the counts and capture the new miss address.
        nxt_state = (miss_detected) ? WAIT : IDLE;  // Go to the WAIT state to capture the address of the cache miss.
      end

      default : begin // ERROR state - invalid state.
        nxt_state = IDLE;        // Go to IDLE state on error.
        clr_count = 1'b0;        // By default, assume we are not clearing the counts.
        fsm_busy = 1'b0;         // By default, assume the FSM is not busy.
        incr_cnt = 1'b0;         // By default, assume we are not incrementing the word count.
        memory_data_out = 16'h0000; // By default, assume we are not writing to memory.
        write_data_array = 1'b0; // By default, assume we are not writing to the cache data array.
        write_tag_array = 1'b0;  // By default, assume we are not writing to the tag array.
        error = 1'b1;            // Default error state.
      end
    endcase
  end

endmodule

`default_nettype wire // Reset default behavior at the end