`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////////////////
// memory_system.v: Wrapper connecting Cache and Cache_Control //
//                                                             //
// Handles memory requests by first checking the cache.        //
// On a cache miss, Cache_Control fetches the block            //
// from main memory and updates the cache accordingly.         //
/////////////////////////////////////////////////////////////////
module memory_system (
    input  wire         clk,
    input  wire         rst,                    // Active-high reset
    input  wire         enable,                 // Enable for the memory
    input  wire         on_chip_wr,             // Write enable from on chip
    input  wire [15:0]  on_chip_memory_address, // Address used to index into the cache (can also be the miss address)
    input  wire [15:0]  on_chip_memory_data,    // Memory data coming from the on chip processor core

    input wire          enable_prev,            // Memory enable value from previous cycle
    input wire          hit_prev,               // Hit result from previous cycle
    input wire          first_tag_LRU_prev,     // First tag LRU bit from previous cycle
    input wire          first_match_prev,       // First tag match result from previous cycle

    // External memory interface
    input  wire [15:0]  off_chip_memory_data,    // Memory data coming from main memory (DRAM)
    input  wire         memory_data_valid,       // Indicates valid data from main memory is coming through

    output wire [15:0]  off_chip_memory_address, // Address used to index into the off chip DRAM to grab data not in cache

    output wire         fsm_busy,                // Stalls the processor in the case of a cache miss
    output wire [15:0]  data_out                 // Data output read from the cache
);

    /////////////////////////////////////////////////
    // Declare any internal signals as type wire  //
    ///////////////////////////////////////////////
    wire wr_data_enable;             // Condition to write to cache data array
    wire wr_tag_enable;              // Condition to write to cache tag array
    /******************** CACHE SIGNALS **************************************/
    wire [15:0] data_in;             // Data input to the cache (on-chip or memory)
    wire [15:0] tag_in;              // Tag to be written to tag array
    wire first_match;                // Indicates if first way matched
    wire [2:0] first_tag_LRU;        // LRU index output from cache
    wire hit;                        // Indicates a cache hit
    /******************** CACHE CONTROLLER SIGNALS ***************************/
    wire write_data_array;          // FSM signal to write data array
    wire write_tag_array;           // FSM signal to write tag array
    wire [15:0] main_mem_data;       // Data input from main memory
    wire Set_First_LRU;             // Update LRU metadata
    wire evict_first_way;           // Signals if first way is being evicted
    ///////////////////////////////////////////////

    ///////////////////////////
    // Instantiate L1-cache //
    /////////////////////////
    Cache iL1_CACHE (
        .clk(clk),
        .rst(rst),  
        .addr(on_chip_memory_address),
        
        .data_in(data_in),
        .write_data_array(wr_data_enable),

        .TagIn(tag_in),
        .evict_first_way(evict_first_way), 
        .Set_First_LRU(Set_First_LRU),        
        .hit_prev(hit_prev),
        
        .data_out(data_out),
        .first_tag_LRU(first_tag_LRU),
        .first_match(first_match),
        .hit(hit)
    );
    
    // We write to the cache either when we have a hit and we are writing from on-chip, or we 
    // have a miss and writing from off chip.
    assign wr_data_enable = (enable) & ((hit) ? on_chip_wr : write_data_array);

    // We write to the tag array when we the cache was enabled in the previous cycle and we finish a miss cycle or when a cache hit occurred in the previous cycle.
    assign wr_tag_enable = (enable_prev) & (hit_prev | write_tag_array);

    // The data input to the cache is either the main memory data or the on-chip data.
    assign data_in = (hit) ? on_chip_memory_data : main_mem_data;
    /////////////////////////

    ///////////////////////////////////////
    // Instantiate L1-Cache controller  //
    /////////////////////////////////////
    Cache_Control iL1_CACHE_CONTROLLER (
        .clk(clk),
        .rst(rst),
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
    //////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end
