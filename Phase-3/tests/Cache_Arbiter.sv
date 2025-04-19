//////////////////////////////////////////////////
// Cache_Arbiter_model.sv                       //
// This module arbitrates memory access between //
// the I-cache and D-cache during cache misses. //
// Only one cache may access memory at a time.  //
// The I-cache is given priority over the       //
// D-cache when both request memory.            //
//////////////////////////////////////////////////
module Cache_Arbiter_model (
    input logic clk,                  // Clock signal
    input logic rst,                  // Active-high reset

    input logic ICACHE_busy,          // High when I-cache is handling a miss
    input logic DCACHE_busy,          // High when D-cache is handling a miss

    output logic mem_en,              // Enables main memory on a cache miss
    output logic i_grant,             // Grant signal to I-cache
    output logic d_grant              // Grant signal to D-cache
);

    /////////////////////////////////////////////////
    // Declare any internal signals as type wire  //
    ///////////////////////////////////////////////
    logic i_grant_next; // Grants the intruction cache to access main memory.
    logic d_grant_next; // Grants the data cache to access main memory.
    ///////////////////////////////////////////////

    //////////////////////////////////////////////////////////////
    // Combinational logic for arbitration                      //
    // If both caches are busy, I-cache is granted memory first //
    // and correspondingly, memory is enabled                   //
    //////////////////////////////////////////////////////////////
    assign i_grant_next = ICACHE_busy;
    assign d_grant_next = ~ICACHE_busy & DCACHE_busy;
    assign mem_en_nxt = i_grant_next | d_grant_next;

    //////////////////////////////////////////////////////////////
    // Grants are asserted only while the corresponding FSM is  //
    // busy and arbitration chooses that cache.                 //
    //////////////////////////////////////////////////////////////
    always @(posedge clk) begin
        if (rst)
            mem_en <= 1'b0;
        else
            mem_en <= mem_en_nxt;
    end

    always @(posedge clk) begin
        if (rst)
            i_grant <= 1'b0;
        else
            i_grant <= i_grant_next;
    end

    always @(posedge clk) begin
        if (rst)
            d_grant <= 1'b0;
        else
            d_grant <= d_grant_next;
    end

endmodule

`default_nettype wire // Reset default behavior at the end