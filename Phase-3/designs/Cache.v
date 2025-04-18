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
  input  wire [15:0]  DataIn,              // Data (instruction or word) to write into the cache
  input  wire         MEM_WB_WaySelect,    // The line which had a hit or the block to evict the cycle we update the tag array
  input  wire         WriteDataArray,      // Write enable for data array

  // Meta data array control signals
  input wire [7:0] TagIn_first_way,        // First "way" tag info (6-bit tag, 1-bit valid, 1-bit LRU).
  input wire [7:0] TagIn_second_way,       // Second "way" tag info (6-bit tag, 1-bit valid, 1-bit LRU)
  input wire        WriteTagArray,         // Write enable for meta data array

  // Outputs
  output wire [7:0] TagOut_first_way,      // The tag currently stored in the first line of the cache to compare to.
  output wire [7:0] TagOut_second_way,     // The tag currently stored in the second line of the cache to compare to.
  output wire [15:0]  DataOut,             // Output data from cache (e.g., fetched instruction or memory word)
  output wire      WaySelect,              // The line which had a hit or the block to evict this cycle after a read or a write
  output wire         hit                  // Indicates cache hit or miss
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire [63:0] set_enable;      // One hot set enable for the 64 sets in the cache.
  wire [7:0] word_enable;      // One hot word enable based on the b-bits of the address.
  wire first_match;            // 1-bit signal indicating the first "way" in the set caused a cache hit.
  wire second_match;           // 1-bit signal indicating the second "way" in the set caused a cache hit.
  wire evict_way;              // 1-bit signal indicating which "way" has LRU bit set.
  ///////////////////////////////////////////////

  // Instantiate a 3:8 decoder to get which word of the 8 words to write to.
  Decoder_3_8 iWORD_DECODER (.RegId(addr[3:1]), en(1'b1), .Wordline(word_enable));

  // Instantiate a 6:64 read decoder to get which set of the 64 sets to enable.
  Decoder_6_64 iSET_DECODER (.RegId(addr[9:4]), .Wordline(set_enable));

  ////////////////////////////////////////////////////////////
  // Implement the L1-cache as structural/dataflow verilog //
  //////////////////////////////////////////////////////////
  // Instantiate the data array for the cache.
  DataArray iDA (
      .clk(clk),
      .rst(rst),
      .Write(WriteDataArray),
      .DataIn(DataIn),
      .WaySelect(MEM_WB_WaySelect),
      .SetEnable(set_enable),
      .WordEnable(word_enable),
      
      .DataOut_first_way(DataOut_first_way),
      .DataOut_second_way(DataOut_second_way)
  );

  // Instantiate the meta data array for the cache.
  MetaDataArray iMDA (
      .clk(clk),
      .rst(rst),
      .Write(WriteTagArray),
      .DataIn_first_way(TagIn_first_way),
      .DataIn_second_way(TagIn_second_way),
      .SetEnable(set_enable),
      
      .DataOut_first_way(TagOut_first_way),
      .DataOut_second_way(TagOut_second_way)
  );

  // Compare the tag stored in the cache currently at both "ways/lines" in parallel, checking for equality and valid bit set. (addr[16:8] == tag and TagOut[1] == valid)
  assign first_match = (addr[16:8] == TagOut_first_way[7:2]) & TagOut_first_way[1];
  assign second_match = (addr[16:8] == TagOut_second_way[7:2]) & TagOut_second_way[1];
  
  // If first_way LRU is 1, evict first_way (0), else evict second_way (1). (TagOut[0] == LRU)
  assign evict_way = (TagOut_first_way[0]) ? 1'b0 : 1'b1; 

  // On a hit, pick the way that matched (If second_match is 1, the second "way" matched, else if 0, the first "way" matched). On a miss, pick the evicted way.
  assign WaySelect = (hit) ? second_match : evict_way;

  // On a cache hit on the first way, we update the tag with the new incoming tag, valid bit set, and LRU bit unset. Else if it did not hit on the first way, we set its LRU bit,
  // and keeping the content the same. Otherwise, if it is a cache miss, and we must evict the first "way", we update it with the new tag along with LRU bit unset. If
  // we don't have to evict the first "way", we set its LRU bit as the the second "way" that is evicted is now most recently used.
  assign TagIn_first_way  = (hit) ?
                              (((first_match) ? {TagOut_first_way[7:1], 1'b0} : {TagOut_first_way[7:1], 1'b1})) :
                              (((~evict_way) ? {tag, 1'b1, 1'b0} : {TagOut_first_way[7:1], 1'b1}));

  // On a cache hit on the second way, we update the tag with the new incoming tag, valid bit set, and LRU bit unset. Else if it did not hit on the first way, we set its LRU bit,
  // and keeping the content the same. Otherwise, if it is a cache miss, and we must evict the second "way", we update it with the new tag along with LRU bit unset. If
  // we don't have to evict the second "way", we set its LRU bit as the first "way" that is evicted is now most recently used.
  assign TagIn_second_way = (hit) ?
                              ((second_match) ? {TagOut_second_way[7:1], 1'b0} : {TagOut_second_way[7:1], 1'b1}) :
                              ((evict_way) ? {tag, 1'b1, 1'b0} : {TagOut_second_way[7:1], 1'b1});

  // It is a cache hit if either of the "ways" resulted in a match, else it is a miss.
  assign hit = first_match | second_match;

  // Grab the data to be output based on which way had a read hit, else if not a read hit, just output 0s.
  assign DataOut = (hit & ~WriteDataArray) ? ((second_match) ? DataOut_second_way : DataOut_first_way) : 16'h0000;

endmodule

`default_nettype wire // Reset default behavior at the end