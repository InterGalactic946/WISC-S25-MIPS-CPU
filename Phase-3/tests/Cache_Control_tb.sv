////////////////////////////////////////////////////////////////////
// Cache_Control_tb.sv: Testbench for the Cache_Control.          //
// Verifies functionality by comparing outputs with a scoreboard  //
// class.                                                         //
////////////////////////////////////////////////////////////////////

module Cache_Control_tb();

  logic clk;                             // Clock signal
  logic rst;                             // Active high reset 
  logic [15:0] mem[0:65535];             // Initial memory
  
  // Cache block structure to hold data and tag.
  typedef struct {
    logic [15:0] data[0:7];              // Cache data array
    logic [15:0] mem_addr[0:7];          // Memory address array
    integer cycle_time[0:8];             // Cycle time array
    logic [7:0] tag;                     // Cache tag
  } cache_block_t;                       // Cache block structure

  logic [3:0] word_count;                // Number of words filled in the cache data array
  integer num_misses;                    // Number of misses to inject
  logic clr_cache;                       // Clear the cache block
  logic write_tag_array_pl;              // Delayed version of write_tag_array
  string miss_detected_cycle;            // Cycle when the miss_detected signal was high
  cache_block_t cache_block;             // Cache block structure to hold data and tag
  
  logic proceed;                         // Allows this instance to proceed.
  logic set_miss_detected;               // Signal to set the miss_detected signal
  logic miss_detected_pl;                // Delayed version of the miss_detected signal
  logic miss_detected;                   // Indicates a cache miss
  logic [15:0] miss_address;             // Address that missed in the cache
  logic [15:0] data_out_4;               // First cycle of read data
  logic [15:0] data_out_3, data_out_2, data_out_1; // Pipelined data
  logic [15:0] memory_data;              // Data returned by memory after delay
  logic data_valid_4;                    // First cycle of memory enable signal
  logic data_valid_3, data_valid_2, data_valid_1; // Pipelined enable signals
  logic memory_data_valid;               // Active high signal indicating valid data returning on memory bus  
    
  logic fsm_busy;                        // High while FSM is busy handling the miss (used as a pipeline stall signal)
  logic miss_mem_en;                     // miss memory enable
  logic [7:0] tag_out;                   // The tag to write into the cache
  logic write_tag_array;                 // Write enable to cache tag array when all words are filled in to data array
  logic write_data_array;                // Write enable to cache data array to signal when filling with memory_data
  logic [15:0] memory_address;           // Address to read from memory
  logic [15:0] cache_memory_address;     // The address to write to the cache on a miss.
  logic [15:0] memory_data_out;          // Data to be written to the cache data array
  
  logic expected_fsm_busy;                    // Expected value of fsm_busy
  logic expected_miss_mem_en;                 // Expected value of memory enable
  logic [7:0] expected_tag_out;               // Expected tag to write into the cache
  logic expected_write_tag_array;             // Expected value of write_tag_array
  logic expected_write_data_array;            // Expected value of write_data_array
  logic [15:0] expected_memory_address;       // Expected value of memory_address
  logic [15:0] expected_cache_memory_address; // The expected address to write to the cache on a miss.
  logic [15:0] expected_memory_data_out;      // Expected value of memory_data_out


  // Instantiate the DUT: Cache Control.  
  Cache_Control iDUT (
    .clk(clk),
    .rst(rst),
    .proceed(proceed),
    .miss_detected(miss_detected),
    .miss_address(miss_address),
    .memory_data_valid(memory_data_valid),
       
    .fsm_busy(fsm_busy),
    .mem_en(miss_mem_en),
                
    .tag_out(tag_out),
    .write_tag_array(write_tag_array),

    .write_data_array(write_data_array),
        
    .main_memory_address(memory_address),
    .cache_memory_address(cache_memory_address)
  );

  // Instantiate the model Cache_Control.
 Cache_Control_model iCACHE_CONTROL (
    .clk(clk),
    .rst(rst),
    .proceed(proceed),
    .miss_detected(miss_detected),
    .miss_address(miss_address),
    .memory_data_valid(memory_data_valid),
       
    .fsm_busy(expected_fsm_busy),
    .mem_en(expected_miss_mem_en),
                
    .tag_out(expected_tag_out),
    .write_tag_array(expected_write_tag_array),

    .write_data_array(expected_write_data_array),
      
    .main_memory_address(expected_memory_address),
    .cache_memory_address(expected_cache_memory_address)
  );

    /* Model the memory */
    /////////////////////////////////////////////////////////
    assign data_out_4 = (miss_mem_en) ? mem[memory_address[15:1]] : 16'h0000;
    assign data_valid_4 = miss_mem_en;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < $size(mem); i++) begin
                mem[i] <= $random;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            // Reset all output and pipeline stages
            data_out_3 <= 16'h0000;
            data_out_2 <= 16'h0000;
            data_out_1 <= 16'h0000;
            memory_data <= 16'h0000;

            data_valid_3 <= 1'b0;
            data_valid_2 <= 1'b0;
            data_valid_1 <= 1'b0;
            memory_data_valid <= 1'b0;
        end else begin
            // Shift data and valid signals through pipeline
            data_out_3 <= data_out_4;
            data_out_2 <= data_out_3;
            data_out_1 <= data_out_2;
            memory_data <= data_out_1;

            data_valid_3 <= data_valid_4;
            data_valid_2 <= data_valid_3;
            data_valid_1 <= data_valid_2;
            memory_data_valid <= data_valid_1;
        end
    end
    /////////////////////////////////////////////////////

  // A task to verify the prediction and target.
  task verify_cache_fill_FSM();
        if (fsm_busy !== expected_fsm_busy) begin
            $display("ERROR: DUT fsm_busy = %b, Model fsm_busy = %b", fsm_busy, expected_fsm_busy);
            $stop();
        end

        if (miss_mem_en !== expected_miss_mem_en) begin
            $display("ERROR: DUT miss_mem_en = %b, Model miss_mem_en = %b", miss_mem_en, expected_miss_mem_en);
            $stop();
        end

        if (tag_out !== expected_tag_out) begin
            $display("ERROR: DUT tag_out = 0x%h, Model tag_out = 0x%h", tag_out, expected_tag_out);
            $stop();
        end

        if (write_tag_array !== expected_write_tag_array) begin
            $display("ERROR: DUT write_tag_array = %b, Model write_tag_array = %b", write_tag_array, expected_write_tag_array);
            $stop();
        end

        if (write_data_array !== expected_write_data_array) begin
            $display("ERROR: DUT write_data_array = %b, Model write_data_array = %b", write_data_array, expected_write_data_array);
            $stop();
        end

        if (memory_address !== expected_memory_address) begin
            $display("ERROR: DUT memory_address = 0x%h, Model memory_address = 0x%h", memory_address, expected_memory_address);
            $stop();
        end

        if (cache_memory_address !== expected_cache_memory_address) begin
            $display("ERROR: DUT cache_memory_address = 0x%h, Model cache_memory_address = 0x%h", cache_memory_address, expected_cache_memory_address);
            $stop();
        end
    endtask


  // At negative edge of clock, verify the predictions match the model.
  always @(negedge clk) begin
    // Verify the DUT other than reset.
    if (!rst) begin
        verify_cache_fill_FSM();
    end
  end


  // Initialize the testbench.
  initial begin
      clk = 1'b0;               // Initially clk is low
      rst = 1'b1;               // Initially rst is high
      set_miss_detected = 1'b0; // Initially set_miss_detected is low
      miss_address = 16'h0000;  // Initially miss_address is 0

      // Wait for the first clock cycle to assert reset
      @(posedge clk);
      
      // Assert reset
      @(negedge clk) rst = 1'b1;

      // Deassert reset and start testing.
      @(negedge clk) rst = 1'b0;

      // Number of total miss injections you want
      num_misses = 15;

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
        // Wait for 15 cycles before injecting the next miss
        repeat (15) @(posedge clk);

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
    if (rst)
       miss_detected <= 1'b0; // Deassert miss_detected signal on reset.
    else if (set_miss_detected) begin
        miss_detected <= 1'b1; // Assert miss_detected signal when set_miss_detected is high.
    end else if (fsm_busy) begin 
        miss_detected <= 1'b1; // Assert miss_detected signal.
    end else begin
        miss_detected <= 1'b0; // Deassert miss_detected signal.
    end
  end

  // Allow to proceed on a miss directly.
  assign proceed = miss_detected;

  // Store the delayed version of miss_detected signal.
  always @(posedge clk) begin
    if (rst) begin
        miss_detected_pl <= 1'b0; // Reset delayed miss_detected signal on reset.
    end else begin
        miss_detected_pl <= miss_detected; // Store the delayed miss_detected signal.
    end
  end


  // Latch the cycle when the miss_detected signal is high.
  always @(posedge clk) begin
    if (rst) begin
        miss_detected_cycle <= ""; // Reset miss_detected_cycle on reset.
    end else if (~miss_detected_pl && miss_detected) begin
        miss_detected_cycle <= $sformatf("@ Cycle %0d", $time/10); // Capture the cycle when miss_detected is high.
    end
  end


  // Model the word count register.
  always @(posedge clk) begin
    if (rst) begin
        word_count <= 4'h0;              // Reset word count on reset.
    end else if (!fsm_busy) begin
        word_count <= 4'h0; // Increment word count when writing to the cache data array and wrap around after 8 words.
    end else if (write_data_array) begin
        word_count <= (word_count + 1'b1) % 8; // Increment word count when writing to the cache data array and wrap around after 8 words.
    end
  end


  // Capture the memory data received from the memory bus.
  always @(posedge clk) begin
    if (rst) begin
        cache_block.data <= '{default: 16'h0000}; // Reset cache_block data to 0 on reset.
        cache_block.mem_addr <= '{default: 16'hxxxx}; // Reset cache_block memory address to x on reset.
        cache_block.cycle_time <= '{default: 0}; // Reset cache_block cycle time to 0 on reset.
        cache_block.tag <= 12'h000; // Reset cache_block tag to 0 on reset.
    end 
    
    if (write_data_array) begin
        cache_block.data[cache_memory_address[3:1]] <= memory_data; // Write the memory data to the cache_block at index word_count.
        cache_block.mem_addr[cache_memory_address[3:1]] <= cache_memory_address; // Write the memory address to the cache_block at index word_count.
        cache_block.cycle_time[cache_memory_address[3:1]] <=  $time/10; // Write the cycle time to the cache_block at index word_count.
    end 
    
    if (write_tag_array) begin
        cache_block.tag <= tag_out; // Write the tag to the cache_block tag.
        cache_block.cycle_time[8] <= $time/10; // Write the cycle time to the cache_block at index 8.
    end
  end


  // Get a delayed version of write_tag_array to print the cache block contents after filling.
  always @(posedge clk) begin
    if (rst) begin
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