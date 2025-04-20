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
    input  logic [7:0]  tag_in,              // The new tag to be written to the cache on a miss
    input logic         write_tag_array,     // Write enable for tag array

    // Outputs
    output logic [15:0] data_out,            // Output data from cache (e.g., fetched instruction or memory word)
    output logic        hit                  // Indicates cache hit or miss in this cycle
);

  ///////////////////////////////////////////////////
  // Internal signal declarations (type: logic)    //
  ///////////////////////////////////////////////////
  logic set_first_LRU;           // Sets the first LRU bit and clears the second.
  logic first_tag_LRU;           // LRU bit of the first tag
  logic evict_first_way;         // Indicates which line we are evicting on a cache miss.
  logic WaySelect;               // The line to write data to either on a hit or a miss.
  logic first_way_match;         // 1-bit signal indicating the first "way" in the set caused a cache hit.
  logic second_way_match;        // 1-bit signal indicating the second "way" in the set caused a cache hit.
  logic [7:0]  first_tag_in;     // Input to the first line in metadata array
  logic [7:0]  second_tag_in;    // Input to the second line in metadata array
  ///////////////////////////////////////////////////

  // Infer the model cache.
  model_cache_t model_cache;

  // Models the 2KB 2-way set associative cache for the model CPU.
  always_ff @(posedge clk) begin
        if (rst) begin
                // Initialize cache data and tag arrays.
            model_cache <= '{
                cache_data_array: '{
                    data_set: '{default: '{
                    first_way:  '{default: '{addr: 16'hxxxx, data: 16'h0000}},  // First way: address = x, data = 0
                    second_way: '{default: '{addr: 16'hxxxx, data: 16'h0000}}   // Second way: address = x, data = 0
                    }}
                },
                cache_tag_array: '{
                    tag_set: '{default: '{
                    first_way:  '{tag: 6'h00, valid: 1'b0, lru: 1'b0},  // First way tag block
                    second_way: '{tag: 6'h00, valid: 1'b0, lru: 1'b0}   // Second way tag block
                    }}
                }
            };
        end 
        
        if (write_data_array) begin // Cache write
                // Check if it’s a hit on "way" 1.
                if (first_way_match) begin
                    // Add the data and address to the first line.
                    model_cache.cache_data_array.data_set[addr[9:4]].first_way[addr[3:1]].addr <= addr;
                    model_cache.cache_data_array.data_set[addr[9:4]].first_way[addr[3:1]].data <= data_in;
                end else if (second_way_match) begin // Cache hit in second way
                    // Add the data to the second line.
                    model_cache.cache_data_array.data_set[addr[9:4]].second_way[addr[3:1]].addr <= addr;
                    model_cache.cache_data_array.data_set[addr[9:4]].second_way[addr[3:1]].data <= data_in;
                end else begin // We are writing but no hit, so we evict a cache line.
                    if (evict_first_way) begin
                        // Add the data and address to the first line.
                        model_cache.cache_data_array.data_set[addr[9:4]].first_way[addr[3:1]].addr <= addr;
                        model_cache.cache_data_array.data_set[addr[9:4]].first_way[addr[3:1]].data <= data_in;
                    end else begin
                        // Add the data and address to the second line.
                        model_cache.cache_data_array.data_set[addr[9:4]].second_way[addr[3:1]].addr <= addr;
                        model_cache.cache_data_array.data_set[addr[9:4]].second_way[addr[3:1]].data <= data_in;
                    end
                end
        end 
        
        if (write_tag_array) begin // Update the both tag lines accordingly.
            model_cache.cache_tag_array.tag_set[addr[9:4]].first_way.tag <= first_tag_in[7:2];
            model_cache.cache_tag_array.tag_set[addr[9:4]].first_way.valid <= first_tag_in[1];
            model_cache.cache_tag_array.tag_set[addr[9:4]].first_way.lru <= set_first_LRU;
            model_cache.cache_tag_array.tag_set[addr[9:4]].second_way.tag <= second_tag_in[7:2];
            model_cache.cache_tag_array.tag_set[addr[9:4]].second_way.valid <= second_tag_in[1];
            model_cache.cache_tag_array.tag_set[addr[9:4]].second_way.lru <= ~set_first_LRU;
        end
    end

  // We write to the second line if the second "way" had a hit, else "way" 0 on a hit, otherwise we write to the line that is evicted, if evict_first_way is high, we write to first line else second line.
  assign WaySelect = (hit) ? second_way_match : ~evict_first_way;

  // Indicates the first line's LRU bit is set.
  assign first_tag_LRU = model_cache.cache_tag_array.tag_set[addr[9:4]].first_way.lru;

  // If the second cache line's LRU is 1, evict second_way (1), else evict first_way (0). (TagOut[0] == LRU)
  assign evict_first_way = first_tag_LRU;

  // If we have a cache hit and the first line is a match, then we clear the first line's LRU bit. Otherwise, if the second line is a match
  // on a hit, then we set the set the first line's LRU bit. If there is a cache miss and we are evicting the first way, then we clear the
  // first cache line's LRU bit and set the second's, Otherwise, if the second way is evicted on a miss, then we set the first line's LRU bit 
  // and clear the second line's.
  assign set_first_LRU = (hit) ? ~first_way_match : ~evict_first_way;

  // If we had a hit on the this cycle, we keep the same tag, but internally update the LRU bits for each line.
  // Else if it is an eviction, we take the new tag to write in the corresponding line.
  assign first_tag_in = (hit) ? model_cache.cache_tag_array.tag_set[addr[9:4]].first_way.tag : ((evict_first_way) ? tag_in : model_cache.cache_tag_array.tag_set[addr[9:4]].first_way.tag);
  assign second_tag_in = (hit) ? model_cache.cache_tag_array.tag_set[addr[9:4]].second_way.tag : ((~evict_first_way) ? tag_in : model_cache.cache_tag_array.tag_set[addr[9:4]].second_way.tag);

  // Compare the tag stored in the cache currently at both "ways/lines" in parallel, checking for equality and valid bit set.
  assign first_way_match = (addr[15:10] == model_cache.cache_tag_array.tag_set[addr[9:4]].first_way.tag) & model_cache.cache_tag_array.tag_set[addr[9:4]].first_way.valid;
  assign second_way_match = (addr[15:10] == model_cache.cache_tag_array.tag_set[addr[9:4]].second_way.tag) & model_cache.cache_tag_array.tag_set[addr[9:4]].second_way.valid;
  
  // It is a cache hit if either of the "ways" resulted in a match, else it is a miss.
  assign hit = first_way_match | second_way_match;

  // Grab the data to be output based on which way had a read hit, else if not a read hit, just output 0s.
  assign DataOut = (hit & ~write_data_array) ? ((second_way_match) ? model_cache.cache_data_array.data_set[addr[9:4]].second_way[addr[3:1]].data : model_cache.cache_data_array.data_set[addr[9:4]].first_way[addr[3:1]].data) : 16'h0000;

endmodule

`default_nettype wire // Reset default behavior at the end