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
  input  wire [5:0]   tag,                 // Tag input from the address to compare
  input  wire [63:0] SetEnable,            // One-hot set enable for (2-ways, 64 sets)

  // Data array control signals
  input  wire [15:0]  DataIn,              // Data (instruction or word) to write into the cache
  input  wire         WriteDataArray,      // Write enable for data array
  input  wire  [7:0]  WordEnable,          // One-hot word enable for selecting 1 of 8 words in block

  // Meta data array control signals
  input  wire         WriteTagArray,       // Write enable for meta data array

  // Outputs
  output wire [15:0]  DataOut,             // Output data from cache (e.g., fetched instruction or memory word)
  output wire         hit                  // Indicates cache hit or miss
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire WaySelect;              // The line which had a hit or the block to evict.
  wire [7:0] TagIn_first_way;  // First "way" tag info (6-bit tag, 1-bit valid, 1-bit LRU).
  wire [7:0] TagIn_second_way; // Second "way" tag info (6-bit tag, 1-bit valid, 1-bit LRU)
  wire [7:0] TagOut_first_way; // The tag currently stored in the first line of the cache to compare to.
  wire [7:0] TagOut_second_way;// The tag currently stored in the second line of the cache to compare to.
  wire [15:0] DataOut_first_way;
  wire [15:0] DataOut_second_way;
  wire [7:0] TagIn;
  wire first_match;            // 1-bit signal indicating the first "way" in the set caused a cache hit.
  wire second_match;           // 1-bit signal indicating the second "way" in the set caused a cache hit.
  wire evict_way;              // 1-bit signal indicating which "way" has LRU bit set.
  ///////////////////////////////////////////////

  ////////////////////////////////////////////////////////////
  // Implement the L1-cache as structural/dataflow verilog //
  //////////////////////////////////////////////////////////
  // Instantiate a data array for the cache.
  DataArray iDA (.clk(clk), .rst(rst), .DataIn(DataIn), .Write(WriteDataArray), .WaySelect(WaySelect), .SetEnable(SetEnable), .WordEnable(WordEnable), .DataOut_first_way(DataOut_first_way), .DataOut_second_way(DataOut_second_way));

  // Instantiate the meta data array for the cache.
  MetaDataArray iMDA (.clk(clk), .rst(rst), .DataIn(TagIn), .Write(WriteTagArray), .DataIn_first_way(TagIn_first_way), .DataIn_second_way(TagIn_second_way), .SetEnable(SetEnable), .DataOut_first_way(TagOut_first_way), .DataOut_second_way(TagOut_second_way));

  // Compare the tag stored in the cache currently at both "ways/lines" in parallel, checking for equality and valid bit set. (TagOut[7:2] == tag and TagOut[1] == valid)
  assign first_match = (tag == TagOut_first_way[7:2]) & TagOut_first_way[1];
  assign second_match = (tag == TagOut_second_way[7:2]) & TagOut_second_way[1];

  // It is a cache hit if either of the "ways" resulted in a match, else it is a miss.
  assign hit = first_match | second_match;
  
  // If first_way LRU is 1, evict first_way (0), else evict second_way (1). (TagOut[0] == LRU)
  assign evict_way = (TagOut_first_way[0]) ? 1'b0 : 1'b1; 

  // On a hit, pick the way that matched (If second_match is 1, the second "way" matched, else if 0, the first "way" matched). On a miss, pick the evicted way.
  assign WaySelect = (hit) ? second_match : evict_way;

  // On a cache hit on the first way, we update the tag with the new incoming tag, valid bit set, and LRU bit unset. Else if it did not hit on the first way, we set its LRU bit,
  // and keeping the content the same. Otherwise, if it is a cache miss, and we must evict the first "way", we update it with the new tag along with LRU bit unset. If
  // we don't have to evict the first "way", we set its LRU bit as the the second "way" that is evicted is now most recently used.
  assign TagIn_first_way  = (hit) ?
                              (((first_match) ? {tag, 1'b1, 1'b0} : {TagOut_first_way[7:1], 1'b1})) :
                              (((~WaySelect) ? {tag, 1'b1, 1'b0} : {TagOut_first_way[7:1], 1'b1}));

  // On a cache hit on the second way, we update the tag with the new incoming tag, valid bit set, and LRU bit unset. Else if it did not hit on the first way, we set its LRU bit,
  // and keeping the content the same. Otherwise, if it is a cache miss, and we must evict the second "way", we update it with the new tag along with LRU bit unset. If
  // we don't have to evict the second "way", we set its LRU bit as the first "way" that is evicted is now most recently used.
  assign TagIn_second_way = (hit) ?
                              ((second_match) ? {tag, 1'b1, 1'b0} : {TagOut_second_way[7:1], 1'b1}) :
                              ((WaySelect) ? {tag, 1'b1, 1'b0} : {TagOut_second_way[7:1], 1'b1});

  // Grab the data to be output based on which way had a hit, else if not a hit, just output 0s.
  assign DataOut = (hit) ? ((WaySelect) ? DataOut_second_way : DataOut_first_way) : 16'h0000;

endmodule

`default_nettype wire // Reset default behavior at the end
