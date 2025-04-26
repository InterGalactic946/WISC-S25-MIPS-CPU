//////////////////////////////////////////////////////////////////////////////
// memory_system_model.sv: Wrapper connecting Cache and Cache_Control       //
//                                                                          //
// Handles memory requests by first checking the cache.                     //
// On a cache miss, Cache_Control fetches the block from main memory        //
// and updates the cache accordingly.                                       //
//////////////////////////////////////////////////////////////////////////////
module memory_system (
    input  logic        clk,                    // Clock signal
    input  logic        rst,                    // Active-high reset
    input  logic        enable,                 // Enable signal for memory access
    input  logic        proceed,                // Proceed flag to access main memory
    input  logic        on_chip_wr,             // Write enable from on-chip core
    input  logic [15:0] on_chip_memory_address, // Address from processor core
    input  logic [15:0] on_chip_memory_data,    // Data from processor core

    // Interface to external memory
    input  logic [15:0] off_chip_memory_data,   // Data from external memory
    input  logic        memory_data_valid,      // Valid signal from external memory

    output logic [15:0] off_chip_memory_address, // Address to external memory
    
    output logic         miss_mem_en,            // Enables main memory on a cache miss

    output logic [15:0] data_out,               // Data read from cache
    output logic        hit                     // Cache hit signal
);

    ////////////////////////////////////////////////////////
    // Internal logic declarations for Cache and Control //
    //////////////////////////////////////////////////////
    logic wr_data_enable;        // Enable to write data to cache
    logic wr_tag_enable;         // Enable to write tag to cache
    /******************** CACHE SIGNALS **************************************/
    logic [15:0] addr;           // The address to read from/write to.
    logic [15:0] data_in;        // Data input to the cache (on-chip or memory)
    logic [7:0] tag_in;          // Tag to be written to tag array
    /******************** CACHE CONTROLLER SIGNALS ***************************/
    logic fsm_busy;              // Indicates the cache it is busy filling it with data on a miss.
    logic miss_detected;         // A miss is detected when cache is enabled and it is not a hit.
    logic [15:0] controller_memory_address; // The address to write to the cache on a miss.
    logic write_data_array;      // FSM signal to write data array
    logic write_tag_array;       // FSM signal to write tag array
    /////////////////////////////////////////////////////////

    //////////////////////////
    // Instantiate L1 Cache //
    //////////////////////////
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
    assign data_in = (fsm_busy) ? off_chip_memory_data : on_chip_memory_data;
    /////////////////////////

    ////////////////////////////////
    // Instantiate Cache Control //
    ////////////////////////////////
    Cache_Control iL1_CACHE_CONTROLLER (
        .clk(clk),
        .rst(rst),
        .proceed(proceed),
        .miss_detected(miss_detected),
        .miss_address(on_chip_memory_address),
        .memory_data_valid(memory_data_valid),
        
        .fsm_busy(fsm_busy),
        .mem_en(miss_mem_en),
                
        .tag_out(tag_in),
        .write_tag_array(write_tag_array),

        .write_data_array(write_data_array),
        
        .main_memory_address(off_chip_memory_address),
        .cache_memory_address(controller_memory_address)
    );

    assign miss_detected = (enable & ~hit);
    ////////////////////////////////////

endmodule