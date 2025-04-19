///////////////////////////////////////////////////////////////////
// Cache_model.sv: 2KB 2-way set associative cache core module   //
// This module implements a 2KB 2-way set associative            //
// cache for use as either an instruction cache (I-cache)        //
// or a data cache (D-cache) for use in the CPU.                 //
///////////////////////////////////////////////////////////////////

import Monitor_tasks::*;

module Cache_model (
    input  logic        clk,                 // System clock
    input  logic        rst,                 // Active high synchronous reset
    input  logic [15:0] addr,                // Address of the memory to access

    // Data array control signals
    input  logic [15:0] data_in,             // Data (instruction or word) to write into the cache
    input  logic        write_data_array,    // Write enable for data array

    // Meta data array control signals
    input  logic [7:0]  TagIn,               // The new tag to be written to the cache on a miss
    input  logic        evict_first_way,     // Indicates which line we are evicting on a cache miss
    input  logic        Set_First_LRU,       // Signal to set the LRU bit of the first line
    input  logic        hit_prev,            // Indicates a hit occurred on the previous cycle

    // Outputs
    output logic [15:0] data_out,            // Output data from cache (e.g., fetched instruction or memory word)
    output logic        first_tag_LRU,       // LRU bit of the first tag
    output logic        first_match,         // Indicates if the first "way" in the set caused a cache hit
    output logic        hit                  // Indicates cache hit or miss in this cycle
);

  ///////////////////////////////////////////////////
  // Internal signal declarations (type: logic)    //
  ///////////////////////////////////////////////////
  logic [63:0] set_enable;       // One-hot set enable for the 64 sets in the cache
  logic [7:0]  word_enable;      // One-hot word enable based on the b-bits of the address
  logic [7:0]  first_tag_in;     // Input to the first line in metadata array
  logic [7:0]  second_tag_in;    // Input to the second line in metadata array
  logic [7:0]  first_tag_out;    // The tag currently stored in the first line of the cache
  logic [7:0]  second_tag_out;   // The tag currently stored in the second line of the cache
  ///////////////////////////////////////////////////

  // Infer the model cache.
  model_cache_t cache_model;

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

  // Write logic: Always block to handle initialization and cache writes
  always_ff @(posedge clk) begin
        if (rst) begin
            // Initialize the tag array on reset
            for (int i = 0; i < 64; i++) begin
                cache.cache_tag_array.tag_set[i].first_way.valid <= 1'b0;
                cache.cache_tag_array.tag_set[i].first_way.lru <= 1'b0;
                cache.cache_tag_array.tag_set[i].first_way.tag <= 6'h0;
                cache.cache_tag_array.tag_set[i].first_way.addr <= 16'hxxxx;

                cache.cache_tag_array.tag_set[i].second_way.valid <= 1'b0;
                cache.cache_tag_array.tag_set[i].second_way.lru <= 1'b0;
                cache.cache_tag_array.tag_set[i].second_way.tag <= 6'h0;
                cache.cache_tag_array.tag_set[i].second_way.addr <= 16'hxxxx;
                
                // Initialize data array (set all to zero)
                for (int j = 0; j < 8; j++) begin
                    cache.cache_data_array.data_set[i].first_way[j] <= 8'h00;
                    cache.cache_data_array.data_set[i].second_way[j] <= 8'h00;
                end
            end
        end else if (write_data_array) begin
            // Cache write operation: Write data to cache if it's a miss or during direct write
            // Here, we assume that the input address is split into tag and index parts
            logic [5:0] tag = addr[15:10];  // Extract tag from address
            logic [5:0] index = addr[9:4];  // Extract set index
            logic [3:0] block_offset = addr[3:0];  // Extract block offset

            // Check if it’s a hit or miss
            if (cache.cache_tag_array.tag_set[index].first_way.valid && 
                cache.cache_tag_array.tag_set[index].first_way.tag == tag) begin
                // Cache hit in first way
                data_out <= cache.cache_data_array.data_set[index].first_way[block_offset];
                hit <= 1'b1;
                
                // Update LRU bit for the first way
                cache.cache_tag_array.tag_set[index].first_way.lru <= 1'b0;
                cache.cache_tag_array.tag_set[index].second_way.lru <= 1'b1;
            end else if (cache.cache_tag_array.tag_set[index].second_way.valid && 
                         cache.cache_tag_array.tag_set[index].second_way.tag == tag) begin
                // Cache hit in second way
                data_out <= cache.cache_data_array.data_set[index].second_way[block_offset];
                hit <= 1'b1;
                
                // Update LRU bit for the second way
                cache.cache_tag_array.tag_set[index].second_way.lru <= 1'b0;
                cache.cache_tag_array.tag_set[index].first_way.lru <= 1'b1;
            end else begin
                // Cache miss, handle eviction and write data to cache
                hit <= 1'b0;
                
                // Example: Evict first way if both are valid
                if (cache.cache_tag_array.tag_set[index].first_way.valid && 
                    cache.cache_tag_array.tag_set[index].second_way.valid) begin
                    if (cache.cache_tag_array.tag_set[index].first_way.lru) begin
                        // Evict first way, write new data to first way
                        cache.cache_tag_array.tag_set[index].first_way.tag <= tag;
                        cache.cache_data_array.data_set[index].first_way[block_offset] <= data_in;
                        cache.cache_tag_array.tag_set[index].first_way.valid <= 1'b1;
                    end else begin
                        // Evict second way, write new data to second way
                        cache.cache_tag_array.tag_set[index].second_way.tag <= tag;
                        cache.cache_data_array.data_set[index].second_way[block_offset] <= data_in;
                        cache.cache_tag_array.tag_set[index].second_way.valid <= 1'b1;
                    end
                end else begin
                    // If one way is invalid, write directly to the invalid way
                    if (!cache.cache_tag_array.tag_set[index].first_way.valid) begin
                        cache.cache_tag_array.tag_set[index].first_way.tag <= tag;
                        cache.cache_data_array.data_set[index].first_way[block_offset] <= data_in;
                        cache.cache_tag_array.tag_set[index].first_way.valid <= 1'b1;
                    end else if (!cache.cache_tag_array.tag_set[index].second_way.valid) begin
                        cache.cache_tag_array.tag_set[index].second_way.tag <= tag;
                        cache.cache_data_array.data_set[index].second_way[block_offset] <= data_in;
                        cache.cache_tag_array.tag_set[index].second_way.valid <= 1'b1;
                    end
                end
            end
        end
  end


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
  assign first_match = (addr[16:8] == first_tag_out[7:2]) & first_tag_out[1];
  assign second_match = (addr[16:8] == second_tag_out[7:2]) & second_tag_out[1];
  
  // It is a cache hit if either of the "ways" resulted in a match, else it is a miss.
  assign hit = first_match | second_match;

  // Grab the data to be output based on which way had a read hit, else if not a read hit, just output 0s.
  assign DataOut = (hit & ~write_data_array) ? ((second_match) ? second_data_out : first_data_out) : 16'h0000;

endmodule

`default_nettype wire // Reset default behavior at the end