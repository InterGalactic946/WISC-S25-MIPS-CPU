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
  logic [7:0]  first_tag_in;     // Input to the first line in metadata array
  logic [7:0]  second_tag_in;    // Input to the second line in metadata array
  ///////////////////////////////////////////////////

  // Infer the model cache.
  model_cache_t model_cache;

  // Models the 2KB 2-way set associative cache for the model CPU.
  always_ff @(posedge clk) begin
        if (rst) begin
        // Initialize cache data and tag arrays.
        model_cache <= '{default:                   // Initialize all entries of the cache like this, a default data array, and default tag array.
                        '{default:                  // Initialize every set of the data array to a default value.
                           '{default:              // initialize each set of the data array to a default value.
                            '{first_way: 16'h0000 ,  second_way: 16'h0000}
                            }
                        }, 
                        '{default:                  // Initialize every entry of the tag array to a default value.
                            '{default:              // Initialize each set of the tag array to a default value.
                            
                            '{default:              // Initialize each of the lines in each set to a default value.
                                '{addr: 16'hxxxx, tag: 6'h00, valid: 1'b0, lru: 1'b0},
                                '{addr: 16'hxxxx, tag: 6'h00, valid: 1'b0, lru: 1'b0}
                            }
                            }
                         }
                        };
        end else if (write_data_array) begin // Cache write
                // Check if it’s a hit on "way" 1.
                if (first_match)
                    // Add the data to the first line.
                    cache.cache_data_array.data_set[addr[9:4]].first_way[addr[3:1]] <= data_in;
                else if (second_match) // Cache hit in second way
                    // Add the data to the second line.
                    cache.cache_data_array.data_set[addr[9:4]].second_way[addr[3:1]] <= data_in;
                else begin // We are writing but no hit, so we evict a cache line.
                    if (evict_first_way)
                        // Add the data to the first line.
                        cache.cache_data_array.data_set[addr[9:4]].first_way[addr[3:1]] <= data_in;
                    else
                        // Add the data to the second line.
                        cache.cache_data_array.data_set[addr[9:4]].second_way[addr[3:1]] <= data_in;
                end
        end else if (write_tag_array) begin // Update the both tag lines accordingly.
            cache.cache_data_array.tag_set[addr[9:4]].first_way.tag <= first_tag_in[7:2];
            cache.cache_data_array.tag_set[addr[9:4]].first_way.valid <= first_tag_in[1];
            cache.cache_data_array.tag_set[addr[9:4]].first_way.lru <= Set_First_LRU;
            cache.cache_data_array.data_set[addr[9:4]].second_way.tag <= second_tag_in[7:2];
            cache.cache_data_array.data_set[addr[9:4]].second_way.valid <= second_tag_in[1];
            cache.cache_data_array.data_set[addr[9:4]].second_way.lru <= ~Set_First_LRU;
        end
    end

  // Indicates the first line's LRU bit is set.
  assign first_tag_LRU = cache.cache_tag_array.tag_set[addr[9:4]].first_way.lru;

  // If we had a hit on the previous cycle, we keep the same tag, but internally update the LRU bits for each line.
  // Else if it is an eviction, we take the new tag to write in the corresponding line.
  assign first_tag_in = (hit_prev) ? cache.cache_tag_array.tag_set[addr[9:4]].first_way.tag : ((evict_first_way) ? TagIn : cache.cache_tag_array.tag_set[addr[9:4]].first_way.tag);
  assign second_tag_in = (hit_prev) ? cache.cache_tag_array.tag_set[addr[9:4]].second_way.tag : ((~evict_first_way) ? TagIn : cache.cache_tag_array.tag_set[addr[9:4]].second_way.tag);

  // Compare the tag stored in the cache currently at both "ways/lines" in parallel, checking for equality and valid bit set.
  assign first_match = (addr[15:10] == cache.cache_tag_array.tag_set[addr[9:4]].first_way.tag) & cache.cache_tag_array.tag_set[addr[9:4]].first_way.valid;
  assign second_match = (addr[15:10] == cache.cache_tag_array.tag_set[addr[9:4]].second_way.tag) & cache.cache_tag_array.tag_set[addr[9:4]].second_way.valid;
  
  // It is a cache hit if either of the "ways" resulted in a match, else it is a miss.
  assign hit = first_match | second_match;

  // Grab the data to be output based on which way had a read hit, else if not a read hit, just output 0s.
  assign DataOut = (hit & ~write_data_array) ? ((second_match) ? cache.cache_data_array.data_set[addr[9:4]].second_way[addr[3:1]] : cache.cache_data_array.data_set[addr[9:4]].first_way[addr[3:1]]) : 16'h0000;

endmodule

`default_nettype wire // Reset default behavior at the end