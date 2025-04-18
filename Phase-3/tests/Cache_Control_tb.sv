////////////////////////////////////////////////////////////////////
// Cache_Control_tb.sv: Testbench for the Cache_Control.          //
// Verifies functionality by comparing outputs with a scoreboard  //
// class.                                                         //
////////////////////////////////////////////////////////////////////

module Cache_Control_tb();

  logic clk;                             // Clock signal
  logic rst;                             // Active high reset 
  logic rst_n;                           // Active low reset signal
  
  // Cache block structure to hold data and tag.
  typedef struct {
    logic [15:0] data[0:7];              // Cache data array
    logic [15:0] mem_addr[0:7];          // Memory address array
    integer cycle_time[0:8];             // Cycle time array
    logic [7:0] tag;                     // Cache tag
  } cache_block_t;                       // Cache block structure

  logic [2:0] cycle_count;               // Cycle count for the FSM
  logic [3:0] word_count;                // Number of words filled in the cache data array
  integer num_misses;                    // Number of misses to inject
  logic clr_cache;                       // Clear the cache block
  logic write_tag_array_pl;              // Delayed version of write_tag_array
  string miss_detected_cycle;            // Cycle when the miss_detected signal was high
  cache_block_t cache_block;             // Cache block structure to hold data and tag
  
  logic set_miss_detected;               // Signal to set the miss_detected signal
  logic miss_detected_pl;                // Delayed version of the miss_detected signal
  logic miss_detected;                   // Indicates a cache miss
  logic [15:0] miss_address;             // Address that missed in the cache
  logic [15:0] memory_data;              // Data returned by memory after delay
  logic memory_data_valid;               // Active high signal indicating valid data returning on memory bus  
    
  logic fsm_busy;                        // High while FSM is busy handling the miss (used as a pipeline stall signal)
  logic write_data_array;                // Write enable to cache data array to signal when filling with memory_data
  logic write_tag_array;                 // Write enable to cache tag array when all words are filled in to data array
  logic [15:0] memory_address;           // Address to read from memory
  logic [15:0] memory_data_out;          // Data to be written to the cache data array
  
  logic expected_fsm_busy;                // Expected value of fsm_busy
  logic expected_write_data_array;        // Expected value of write_data_array
  logic expected_write_tag_array;         // Expected value of write_tag_array
  logic [15:0] expected_memory_address;   // Expected value of memory_address
  logic [15:0] expected_memory_data_out;  // Expected value of memory_data_out

  // Make reset active high for modules that require it.
  assign rst = ~rst_n;

  // Instantiate the DUT: Cache Control.  
  Cache_Control iDUT (
    .clk(clk),
    .rst(rst),
    .miss_detected(miss_detected),
    .miss_address(miss_address),
    .memory_data(memory_data),
    .memory_data_valid(memory_data_valid),
    .first_tag_LRU(first_tag_LRU_prev),
    .first_match(first_match_prev),
       
    .fsm_busy(fsm_busy),
                
    .TagIn(tag_in),
    .write_tag_array(write_tag_array),
    .Set_First_LRU(Set_First_LRU),
    .evict_first_way(evict_first_way),

    .write_data_array(write_data_array),
      
    .memory_address(off_chip_memory_address),
    .memory_data_out(main_mem_data)               
  );

  // Instantiate the model Cache_Control.
 Cache_Control_model iCACHE_CONTROL (
    .clk(clk),
    .rst(rst),
    .miss_detected(miss_detected),
    .miss_address(miss_address),
    .memory_data(memory_data),
    .memory_data_valid(memory_data_valid),
    .first_tag_LRU(first_tag_LRU_prev),
    .first_match(first_match_prev),
       
    .fsm_busy(expected_fsm_busy),
                
    .TagIn(expected_tag_in),
    .write_tag_array(expected_write_tag_array),
    .Set_First_LRU(expected_Set_First_LRU),
    .evict_first_way(expected_evict_first_way),

    .write_data_array(expected_write_data_array),
      
    .memory_address(expected_memory_address),
    .memory_data_out(expected_memory_data_out)               
  );

  // A task to verify the prediction and target.
  task verify_cache_fill_FSM();
        if (fsm_busy !== expected_fsm_busy) begin
            $display("ERROR: DUT fsm_busy = %0b, Model fsm_busy = %0b", fsm_busy, expected_fsm_busy);
            $stop();
        end

        if (write_data_array !== expected_write_data_array) begin
            $display("ERROR: DUT write_data_array = %0b, Model write_data_array = %0b", write_data_array, expected_write_data_array);
            $stop();
        end

        if (write_tag_array !== expected_write_tag_array) begin
            $display("ERROR: DUT write_tag_array = %0b, Model write_tag_array = %0b", write_tag_array, expected_write_tag_array);
            $stop();
        end

        if (memory_address !== expected_memory_address) begin
            $display("ERROR: DUT memory_address = %0h, Model memory_address = %0h", memory_address, expected_memory_address);
            $stop();
        end

        if (memory_data_out !== expected_memory_data_out) begin
            $display("ERROR: DUT memory_data_out = %0h, Model memory_data_out = %0h", memory_data_out, expected_memory_data_out);
            $stop();
        end
    endtask


  // At negative edge of clock, verify the predictions match the model.
  always @(negedge clk) begin
    // Verify the DUT other than reset.
    if (rst_n) begin
        verify_cache_fill_FSM();

        // $display("Memory data = 0x%h, Memory address = 0x%h, FSM busy = %0b, Write data array = %0b, Write tag array = %0b, @Cycle = %0d",
        //          memory_data, memory_address, fsm_busy, write_data_array, write_tag_array, $time/10);
        // $display("Memory data out = 0x%h, Word count = %0d, Cycle count = %0d", memory_data_out, word_count, cycle_count);
        // $display("Miss detected = %0b, Miss address = 0x%h, Memory data valid = %0b", miss_detected, miss_address, memory_data_valid);
    end
  end


  // Initialize the testbench.
  initial begin
      clk = 1'b0;              // Initially clk is low
      rst_n = 1'b0;            // Initially rst_n is low
      set_miss_detected = 1'b0; // Initially set_miss_detected is low
      miss_address = 16'h0000; // Initially miss_address is 0
      memory_data = 16'h0000;  // Initially memory_data is 0

      // Wait for the first clock cycle to assert reset
      @(posedge clk);
      
      // Assert reset
      @(negedge clk) rst_n = 1'b0;

      // Deassert reset and start testing.
      @(negedge clk) rst_n = 1'b1;

      // Number of total miss injections you want
      num_misses = 50;

      // Set up the testbench to inject misses into the cache.
      $display("\n");

      // Set the miss_detected signal to 1 to start the FSM.
      @(negedge clk) begin
        miss_address = 16'h0006;
        set_miss_detected = 1'b1;
      end

      // Deassert the miss_detected signal after 1 clock cycle.
      @(negedge clk) set_miss_detected = 1'b0;

      for (int i = 0; i < num_misses; i++) begin
        // Wait for 38 cycles before injecting the next miss
        repeat (38) @(posedge clk);

        // Set a new miss address.
        @(negedge clk) begin
            // Generate a random miss address that is a multiple of 2.
            miss_address = {4'h0, $random} & 16'hFFFE; // Ensure the address is even.
            set_miss_detected = 1'b1;
        end

        // Deassert the miss signal after one cycle
        @(negedge clk) set_miss_detected = 1'b0;
      end

      // If we reached here it means all tests passed.
      $display("\nYAHOO!! All tests passed.");
      $stop();
  end

  always 
    #5 clk = ~clk; // toggle clock every 5 time units.

  // Set the miss_detected signal to 1 when the FSM is busy.
  always @(posedge clk) begin
    if (!rst_n)
       miss_detected <= 1'b0; // Deassert miss_detected signal on reset.
    else if (set_miss_detected) begin
        miss_detected <= 1'b1; // Assert miss_detected signal when set_miss_detected is high.
    end else if (fsm_busy) begin 
        miss_detected <= 1'b1; // Assert miss_detected signal.
    end else begin
        miss_detected <= 1'b0; // Deassert miss_detected signal.
    end
  end


  // Store the delayed version of miss_detected signal.
  always @(posedge clk) begin
    if (!rst_n) begin
        miss_detected_pl <= 1'b0; // Reset delayed miss_detected signal on reset.
    end else begin
        miss_detected_pl <= miss_detected; // Store the delayed miss_detected signal.
    end
  end


  // Latch the cycle when the miss_detected signal is high.
  always @(posedge clk) begin
    if (!rst_n) begin
        miss_detected_cycle <= ""; // Reset miss_detected_cycle on reset.
    end else if (~miss_detected_pl && miss_detected) begin
        miss_detected_cycle <= $sformatf("@ Cycle %0d", $time/10); // Capture the cycle when miss_detected is high.
    end
  end

  // Model the 4 cycle delay of the memory bus.
  always @(posedge clk) begin
    if (!rst_n) begin
        cycle_count <= 3'h0; // Reset cycle count on reset.
    end else if (~miss_detected_pl && miss_detected) begin
        cycle_count <= 3'h0;                     // Reset cycle count when a miss is detected.
    end  else begin
        cycle_count <= (cycle_count + 1'b1) % 4; // Increment cycle count on each clock cycle.
    end
  end


  // Model the word count register.
  always @(posedge clk) begin
    if (!rst_n) begin
        word_count <= 4'h0;              // Reset word count on reset.
    end else if (write_data_array) begin
        word_count <= (word_count + 1'b1) % 8; // Increment word count when writing to the cache data array and wrap around after 8 words.
    end
  end


  // Model the memory data valid signal.
  always @(posedge clk) begin
    if (!rst_n) begin
        memory_data_valid <= 1'b0; // Deassert memory_data_valid signal on reset.
    end else if (cycle_count === 3'h3) begin
        memory_data_valid <= 1'b1; // Assert memory_data_valid signal after 4 cycles.
    end else begin
        memory_data_valid <= 1'b0; // Deassert memory_data_valid signal otherwise.
    end
  end


  // Model the memory data output.
  always @(posedge clk) begin
      if (!rst_n) begin
          memory_data <= 16'h0000; // Reset memory_data to 0 on reset.
      end else if (cycle_count === 3'h3) begin
          memory_data <= $random & 16'hFFFF; // Generate random memory data after 4 cycles.
      end else begin
          memory_data <= 16'h0000; // Set memory_data to 0 otherwise.
      end
  end


  // Capture the memory data received from the memory bus.
  always @(posedge clk) begin
    if (!rst_n) begin
        cache_block.data <= '{default: 16'h0000}; // Reset cache_block data to 0 on reset.
        cache_block.mem_addr <= '{default: 16'hxxxx}; // Reset cache_block memory address to x on reset.
        cache_block.cycle_time <= '{default: 0}; // Reset cache_block cycle time to 0 on reset.
        cache_block.tag <= 12'h000; // Reset cache_block tag to 0 on reset.
    end else if (write_data_array) begin
        cache_block.data[memory_address[3:1]] <= memory_data_out; // Write the memory data to the cache_block at index word_count.
        cache_block.mem_addr[memory_address[3:1]] <= memory_address; // Write the memory address to the cache_block at index word_count.
        cache_block.cycle_time[memory_address[3:1]] <=  $time/10; // Write the cycle time to the cache_block at index word_count.
    end else if (write_tag_array) begin
        cache_block.tag <= miss_address[15:4]; // Write the miss address to the cache_block tag.
        cache_block.cycle_time[8] <= $time/10; // Write the cycle time to the cache_block at index 8.
    end
  end


  // Get a delayed version of write_tag_array to print the cache block contents after filling.
  always @(posedge clk) begin
    if (!rst_n) begin
        write_tag_array_pl <= 1'b0; // Reset delayed write_tag_array signal on reset.
    end else if (write_tag_array) begin
        write_tag_array_pl <= 1'b1; // Assert delayed write_tag_array signal when write_tag_array is high.
    end else if (clr_cache) begin
        write_tag_array_pl <= 1'b0; // Deassert delayed write_tag_array signal otherwise.
    end
  end


  // Clear the cache block when we get a cache miss and only on the first cycle of the miss.
  assign clr_cache = word_count === 4'h0;


  // Print the cache block contents after filling.
  always @(posedge clk) begin
    if (write_tag_array_pl) begin
        $display("======================================================================");
        $display("Miss detected %s, @ Miss address = 0x%h | Completed At Cycle: %0d", miss_detected_cycle, miss_address, ($time/10) - 1);
        $display("======================================================================");
        for (int i = 0; i < 8; i++) begin
            $display("Data[%0d] = 0x%h, Address[%0d] = 0x%h, @ Cycle: %0d", 
                     i, cache_block.data[i], i, cache_block.mem_addr[i], cache_block.cycle_time[i]);
        end
        $display("Tag = 0x%h, @ Cycle: %0d", cache_block.tag, cache_block.cycle_time[8]);
        $display("=======================================================================\n");
    end
  end

endmodule