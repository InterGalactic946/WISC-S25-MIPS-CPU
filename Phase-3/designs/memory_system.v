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
    input  wire         proceed,                // Allows this instance of memory_system to proceed to access main memory, if low, it must stall
    input  wire         on_chip_wr,             // Write enable from on chip
    input  wire [15:0]  on_chip_memory_address, // Address used to index into the cache (can also be the miss address)
    input  wire [15:0]  on_chip_memory_data,    // Memory data coming from the on chip processor core

    // External memory interface
    input  wire [15:0]  off_chip_memory_data,    // Memory data coming from main memory (DRAM)
    input  wire         memory_data_valid,       // Indicates valid data from main memory is coming through

    output wire [15:0]  off_chip_memory_address, // Address used to index into the off chip DRAM to grab data not in cache

    output wire         fsm_busy,                // Stalls the processor in the case of a cache miss
    
    output wire [15:0]  data_out,                // Data output read from the cache
    output wire         hit                      // Indicates a cache hit
);

    /////////////////////////////////////////////////
    // Declare any internal signals as type wire  //
    ///////////////////////////////////////////////
    wire wr_data_enable;             // Condition to write to cache data array
    wire wr_tag_enable;              // Condition to write to cache tag array
    /******************** CACHE SIGNALS **************************************/
    wire [15:0] addr;                // The address to read from/write to.
    wire [15:0] data_in;             // Data input to the cache (on-chip or memory)
    wire [15:0] tag_in;              // Tag to be written to tag array
    /******************** CACHE CONTROLLER SIGNALS ***************************/
    wire [15:0] controller_memory_address; // The address to write to the cache on a miss.
    wire write_data_array;           // FSM signal to write data array
    wire write_tag_array;            // FSM signal to write tag array
    wire [15:0] main_mem_data;       // Data input from main memory
    ///////////////////////////////////////////////

    ///////////////////////////
    // Instantiate L1-cache //
    /////////////////////////
    Cache iL1_CACHE (
        .clk(clk),
        .rst(rst),  
        .addr(addr),
        
        .data_in(data_in),
        .write_data_array(wr_data_enable),

        .tag_in(tag_in),
        .write_tag_array(wr_tag_enable),
        
        .data_out(data_out),
        .hit(hit)
    );

    // We write to / read from the cache at the address specified by the processor when stall is not active, else from the address specified by the controller.
    assign addr = (fsm_busy) ? controller_memory_address : on_chip_memory_address;
    
    // We write to the cache either when we have a hit and we are writing from on-chip, or we 
    // have a miss and writing from off chip.
    assign wr_data_enable = (enable) & ((fsm_busy) ? write_data_array : on_chip_wr);

    // We write to the tag array when we the cache is enabled and there is a hit this cycle or when we finish filling the cache on a miss.
    assign wr_tag_enable = (enable) & (hit | write_tag_array);

    // The data input to the cache is either the main memory data or the on-chip data based on cache miss.
    assign data_in = (fsm_busy) ? main_mem_data : on_chip_memory_data;
    /////////////////////////

    ///////////////////////////////////////
    // Instantiate L1-Cache controller  //
    /////////////////////////////////////
    Cache_Control iL1_CACHE_CONTROLLER (
        .clk(clk),
        .rst(rst),
        .proceed(proceed),
        .miss_detected(~hit),
        .miss_address(on_chip_memory_address),
        .memory_data(off_chip_memory_data),
        .memory_data_valid(memory_data_valid),
        
        .fsm_busy(fsm_busy),
                
        .tag_out(tag_in),
        .write_tag_array(write_tag_array),

        .write_data_array(write_data_array),
        
        .main_memory_address(off_chip_memory_address),
        .cache_memory_address(controller_memory_address),
        .memory_data_out(main_mem_data)               
    );
    //////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end
