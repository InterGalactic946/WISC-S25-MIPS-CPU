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

  // Data array control signals
  input  wire [15:0]  DataIn,              // Data (instruction or word) to write into the cache
  input  wire         WriteDataArray,      // Write enable for data array
  input  wire [127:0] DataBlockEnable,     // One-hot block enable for writing data (2-way, 64 sets)
  input  wire  [7:0]  WordEnable,          // One-hot word enable for selecting 1 of 8 words in block

  // Meta data array control signals
  input  wire  [7:0]  TagIn,               // Tag info (6-bit tag, 1-bit valid, 1-bit LRU)
  input  wire         WriteTagArray,       // Write enable for meta data array
  input  wire [127:0] TagBlockEnable,      // One-hot block enable for writing tag

  // Outputs
  output wire [15:0]  DataOut,             // Output data from cache (e.g., fetched instruction or memory word)
  output wire         hit                  // Indicates cache hit or miss
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire [7:0] TagOut;   // The tag currently stored in the cache to compare to.
  wire tags_match;     // Indicates that the current tag and the tag in the cache match.
  ///////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////
  // Implement the instruction cache as structural/dataflow verilog //
  ///////////////////////////////////////////////////////////////////
  // Instantiate a data array for the cache.
  DataArray iDA (.clk(clk), .rst(rst), .DataIn(DataIn), .Write(WriteDataArray), .BlockEnable(DataBlockEnable), .WordEnable(WordEnable), .DataOut(DataOut));

  // Instantiate the meta data array for the cache.
  MetaDataArray iMDA (.clk(clk), .rst(rst), .DataIn(TagIn), .Write(WriteTagArray), .BlockEnable(TagBlockEnable), .DataOut(TagOut));

  // Compare the tag stored in the cache currently at that "line/way". (TagOut[7:2] == tag_stored)
  assign tags_match = (tag == TagOut[7:2]);

  // It is a hit when the valid bit is set and the tags match. (TagOut[1] == valid)
  assign hit = (tags_match & TagOut[1]);

endmodule

`default_nettype wire // Reset default behavior at the end