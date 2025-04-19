//////////////////////////////////////////////////////////////////////////////
// memory_system_model.sv: Wrapper connecting Cache and Cache_Control       //
//                                                                          //
// Handles memory requests by first checking the cache.                     //
// On a cache miss, Cache_Control fetches the block from main memory        //
// and updates the cache accordingly.                                       //
//////////////////////////////////////////////////////////////////////////////
module memory_system_model (
    input  logic        clk,                    // Clock signal
    input  logic        rst,                    // Active-high reset
    input  logic        enable,                 // Enable signal for memory access
    input  logic        proceed,                // Proceed flag to access main memory
    input  logic        on_chip_wr,             // Write enable from on-chip core
    input  logic [15:0] on_chip_memory_address, // Address from processor core
    input  logic [15:0] on_chip_memory_data,    // Data from processor core

    input  logic        enable_prev,            // Enable value from previous cycle
    input  logic        hit_prev,               // Hit result from previous cycle
    input  logic        first_tag_LRU_prev,     // LRU bit from previous cycle
    input  logic        first_match_prev,       // First tag match from previous cycle

    // Interface to external memory
    input  logic [15:0] off_chip_memory_data,   // Data from external memory
    input  logic        memory_data_valid,      // Valid signal from external memory

    output logic [15:0] off_chip_memory_address, // Address to external memory
    output logic        fsm_busy,                // Busy signal to stall processor

    output logic first_tag_LRU,                 // LRU metadata from cache
    output logic        first_match,            // Indicates first way matched
    output logic [15:0] data_out,               // Data read from cache
    output logic        hit                     // Cache hit signal
);

    //////////////////////////////////////////////////////
    // Internal logic declarations for Cache and Control //
    //////////////////////////////////////////////////////
    logic wr_data_enable;        // Enable to write data to cache
    logic wr_tag_enable;         // Enable to write tag to cache
    logic [15:0] data_in;        // Data input to cache (from core or memory)
    logic [15:0] tag_in;         // Tag to be written to tag array

    logic write_data_array;      // FSM signal to write cache data array
    logic write_tag_array;       // FSM signal to write cache tag array
    logic [15:0] main_mem_data;  // Data input from external memory
    logic Set_First_LRU;         // Control signal to update LRU
    logic evict_first_way;       // Flag for evicting the first way
    /////////////////////////////////////////////////////////

    //////////////////////////
    // Instantiate L1 Cache //
    //////////////////////////
    Cache_model iL1_CACHE (
        .clk(clk),
        .rst(rst),
        .addr(on_chip_memory_address),

        .data_in(data_in),
        .write_data_array(wr_data_enable),
        
        .write_tag_array(wr_tag_enable),
        .TagIn(tag_in),
        .evict_first_way(evict_first_way),
        .Set_First_LRU(Set_First_LRU),
        .hit_prev(hit_prev),

        .data_out(data_out),
        .first_tag_LRU(first_tag_LRU),
        .first_match(first_match),
        .hit(hit)
    );
    //////////////////////////

    /////////////////////////////////////////////////////////
    // Cache write conditions based on hit or FSM control //
    /////////////////////////////////////////////////////////
    assign wr_data_enable = enable && ((hit) ? on_chip_wr : write_data_array);
    assign wr_tag_enable  = enable_prev && (hit_prev || write_tag_array);
    assign data_in        = (hit) ? on_chip_memory_data : main_mem_data;
    /////////////////////////////////////////////////////////

    ////////////////////////////////
    // Instantiate Cache Control //
    ////////////////////////////////
    Cache_Control_model iL1_CACHE_CONTROLLER (
        .clk(clk),
        .rst(rst),
        .proceed(proceed),
        .miss_detected(~hit_prev),
        .miss_address(on_chip_memory_address),
        .memory_data(off_chip_memory_data),
        .memory_data_valid(memory_data_valid),
        .first_tag_LRU(first_tag_LRU_prev),
        .first_match(first_match_prev),

        .fsm_busy(fsm_busy),

        .TagIn(tag_in),
        .write_tag_array(write_tag_array),
        .Set_First_LRU(Set_First_LRU),
        .evict_first_way(evict_first_way),

        .write_data_array(write_data_array),
        .memory_address(off_chip_memory_address),
        .memory_data_out(main_mem_data)
    );
    ////////////////////////////////////

endmodule