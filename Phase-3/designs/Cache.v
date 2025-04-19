`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////////
// Cache.v: 2KB 2-way set associative cache core module   //
// This module implements a 2KB 2-way set associative     //
// cache for use as either an instruction cache (I-cache) //
// or a data cache (D-cache) for use in the CPU.          //
////////////////////////////////////////////////////////////
module Cache (
  input  wire         clk,                 // System clock
  input  wire         rst,                 // Active high synchronous reset
  input  wire [15:0]  addr,                // Address of the memory to access

  // Data array control signals
  input  wire [15:0]  data_in,             // Data (instruction or word) to write into the cache
  input  wire         write_data_array,    // Write enable for data array

  // Meta data array control signals
  input wire       write_tag_array,        // Write enable for tag array
  input wire [7:0] TagIn,                  // The new tag to be written to the cache on a miss
  input wire       evict_first_way,        // Indicates which line we are evicting on a cache miss
  input wire       Set_First_LRU,          // Signal to set the LRU bit of the first line
  input wire       hit_prev,               // Indicates a hit occured on the previous cycle

  // Outputs
  output wire [15:0] data_out,             // Output data from cache (e.g., fetched instruction or memory word)
  output wire first_tag_LRU,               // LRU bit of the first tag
  output wire first_match,                 // 1-bit signal indicating the first "way" in the set caused a cache hit.
  output wire hit                          // Indicates cache hit or miss in this cycle.
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire [63:0] set_enable;      // One hot set enable for the 64 sets in the cache.
  wire [7:0] word_enable;      // One hot word enable based on the b-bits of the address.
  wire [15:0] first_data_out;  // The data currently stored in the first line of the cache.
  wire [15:0] second_data_out; // The data currently stored in the second line of the cache.
  wire second_match;           // 1-bit signal indicating the second "way" in the set caused a cache hit.
  wire [7:0] first_tag_in;     // Input to the first line in MDA.
  wire [7:0] second_tag_in;    // Input to the second line in MDA.
  wire [7:0] first_tag_out;    // The tag currently stored in the first line of the cache to compare to.
  wire [7:0] second_tag_out;   // The tag currently stored in the second line of the cache to compare to.
  ///////////////////////////////////////////////

  // Instantiate a 3:8 decoder to get which word of the 8 words to write to.
  Decoder_3_8 iWORD_DECODER (.RegId(addr[3:1]), .en(1'b1), .Wordline(word_enable));

  // Instantiate a 6:64 read decoder to get which set of the 64 sets to enable.
  Decoder_6_64 iSET_DECODER (.RegId(addr[9:4]), .Wordline(set_enable));

  ////////////////////////////////////////////////////////////
  // Implement the L1-cache as structural/dataflow verilog //
  //////////////////////////////////////////////////////////
  // Instantiate the data array for the cache.
  DataArray iDA (
      .clk(clk),
      .rst(rst),
      .Write(write_data_array),
      .DataIn(data_in),
      .WaySelect(second_match),
      .SetEnable(set_enable),
      .WordEnable(word_enable),
      
      .DataOut_first_way(first_data_out),
      .DataOut_second_way(second_data_out)
  );

  // Indicates the first line's LRU bit is set.
  assign first_tag_LRU = first_tag_out[0];

  // If we had a hit on the previous cycle, we keep the same tag, but internally update the LRU bits for each line.
  // Else if it is an eviction, we take the new tag to write in the corresponding line.
  assign first_tag_in = (hit_prev) ? first_tag_out : ((evict_first_way) ? TagIn : first_tag_out);
  assign second_tag_in = (hit_prev) ? second_tag_out : ((~evict_first_way) ? TagIn : second_tag_out);

  // Instantiate the meta data array for the cache.
  MetaDataArray iMDA (
      .clk(clk),
      .rst(rst),
      .Write(write_tag_array),
      .DataIn_first_way(first_tag_in),
      .DataIn_second_way(second_tag_in),
      .SetEnable(set_enable),
      .Set_First_LRU(Set_First_LRU),
      
      .DataOut_first_way(first_tag_out),
      .DataOut_second_way(second_tag_out)
  );

  // Compare the tag stored in the cache currently at both "ways/lines" in parallel, checking for equality and valid bit set. (addr[16:8] == tag and TagOut[1] == valid)
  assign first_match = (addr[15:10] == first_tag_out[7:2]) & first_tag_out[1];
  assign second_match = (addr[15:10] == second_tag_out[7:2]) & second_tag_out[1];
  
  // It is a cache hit if either of the "ways" resulted in a match, else it is a miss.
  assign hit = first_match | second_match;

  // Grab the data to be output based on which way had a read hit, else if not a read hit, just output 0s.
  assign data_out = (hit & ~write_data_array) ? ((second_match) ? second_data_out : first_data_out) : 16'h0000;

endmodule

`default_nettype wire // Reset default behavior at the end