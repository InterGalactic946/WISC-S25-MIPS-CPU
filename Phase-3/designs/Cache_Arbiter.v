`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////
// Cache_Arbiter.v                              //
// This module arbitrates memory access between //
// the I-cache and D-cache during cache misses. //
// Only one cache may access memory at a time.  //
// The I-cache is given priority over the       //
// D-cache when both request memory.            //
//////////////////////////////////////////////////
module Cache_Arbiter (
    input wire clk,                  // Clock signal
    input wire rst,                  // Active-high reset

    input wire ICACHE_busy,          // High when I-cache is handling a miss
    input wire DCACHE_busy,          // High when D-cache is handling a miss

    output wire mem_en,              // Enables main memory on a cache miss
    output wire i_grant,             // Grant signal to I-cache
    output wire d_grant              // Grant signal to D-cache
);

    /////////////////////////////////////////////////
    // Declare any internal signals as type wire  //
    ///////////////////////////////////////////////
    wire i_grant_next; // Grants the intruction cache to access main memory.
    wire d_grant_next; // Grants the data cache to access main memory.
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
    // Grant registers driven using cpu_register module         //
    // Grants are asserted only while the corresponding FSM is  //
    // busy and arbitration chooses that cache.                 //
    //////////////////////////////////////////////////////////////
    CPU_Register #(.WIDTH(1)) iMEM_EN_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(mem_en_nxt), .data_out(mem_en));
    CPU_Register #(.WIDTH(1)) iI_CACHE_GRANT_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(i_grant_next), .data_out(i_grant));
    CPU_Register #(.WIDTH(1)) iD_CACHE_GRANT_REG (.clk(clk), .rst(rst), .wen(1'b1), .data_in(d_grant_next), .data_out(d_grant));

endmodule

`default_nettype wire // Reset default behavior at the end