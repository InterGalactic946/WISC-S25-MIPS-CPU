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

    // External memory interface
    input  wire [15:0]  off_chip_memory_data,    // Memory data coming from main memory (DRAM)
    input  wire         memory_data_valid,       // Indicates valid data from main memory is coming through
    
    output wire [15:0]  off_chip_memory_address, // Address used to index into the off chip DRAM to grab data not in cache
    
    output wire         fsm_busy,                // Stalls the processor in the case of a cache miss
    output wire [15:0]  data_out,                // Data output read from the cache
);

    /////////////////////////////////////////////////
    // Declare any internal signals as type wire  //
    ///////////////////////////////////////////////
    wire wr_data_enable;       // Condition we write to the cache data array.
    wire wr_tag_enable;        // Condition we write to the cache data array.
    wire [15:0] data_in;       // Data input to the cache.
    wire [15:0] main_mem_data; // Get the data from main memory for input to the cache.
    wire write_data_array;     // Write enable to cache data array to signal when filling with memory_data.
    wire [7:0] word_enable;    // One hot word enable based on the b-bits of the address.
    wire write_tag_array;      // Write enable to cache tag array when all words are filled in to data array.
    wire hit;                  // Indicates that a cache hit occurred at this address.
    ///////////////////////////////////////////////

    ///////////////////////////
    // Instantiate L1-cache //
    /////////////////////////
    Cache iL1_CACHE (
        .clk(clk),
        .rst(rst),  
        .addr(on_chip_memory_address),
        
        .DataIn(data_in),
        .MEM_WB_WaySelect(MEM_WB_WaySelect),
        .WriteDataArray(wr_data_enable),

        .TagIn_first_way(MEM_WB_TagIn_first_way),
        .TagIn_second_way(MEM_WB_TagIn_second_way),         
        .WriteTagArray(wr_tag_enable),
        
        .TagOut_first_way(TagOut_first_way),
        .TagOut_second_way(TagOut_second_way),
        .DataOut(data_out),
        .WaySelect(WaySelect),
        .hit(hit)
    );
    
    // We write to the cache either when we have a hit and we are writing from on-chip, or we 
    // have a miss and writing from off chip.
    assign wr_data_enable = (hit) ? on_chip_wr : write_data_array;

    // The data input to the cache is either the main memory data or the on-chip data.
    assign data_in = (hit) ? on_chip_memory_data : main_mem_data;
    /////////////////////////

    //////////////////////////////////////
    // Instantiate L1-Cache controller //
    ////////////////////////////////////
    Cache_Control iL1_CACHE_CONTROLLER (
        .clk(clk),
        .rst(rst),
        .miss_detected(~hit),
        .miss_address(on_chip_memory_address),
        .memory_data(off_chip_memory_data),
        .memory_data_valid(memory_data_valid),
        
        .fsm_busy(fsm_busy),
        .write_data_array(write_data_array),
        .write_tag_array(write_tag_array),
        .memory_address(off_chip_memory_address),
        .memory_data_out(main_mem_data)               
    );
    //////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end