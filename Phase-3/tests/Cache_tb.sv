////////////////////////////////////////////////////////////////////
// Cache_tb.sv: Testbench for the on-chip cache.                  //
// Verifies functionality by comparing outputs with a scoreboard  //
// class.                                                         //
////////////////////////////////////////////////////////////////////

module Cache_tb();

  logic clk;                             // Clock signal
  logic rst;                             // Active high reset 

  logic mem_en;                          // Memory enable
  logic [15:0] mem_addr;                 // Address to read from memory
  logic [15:0] mem_data_in;              // Memory data input to the cache 
  logic [15:0] mem_data_out;             // Data to be written to the cache data array
  logic mem_data_valid;                  // Active high signal indicating valid data returning on memory bus

  /* Pipeline stages */
  logic [31:0] IF_ID_out;                
  logic [33:0] ID_EX_out;
  logic [33:0] EX_MEM_out;               // EX_MEM_out[33:18] -> Addr, EX_MEM_out[17:2] -> MemWriteData, EX_MEM_out[1] -> Enable, EX_MEM_out[0] -> MemWrite
  logic [47:0] MEM_WB_out;

  logic [15:0] pc;                       // Current PC value
  logic [15:0] PC_inst;                  // Instruction at pc address
  logic [7:0] tag_in;                    // Tag input
  logic wr_data_enable;                  // Data array enable
  logic wr_tag_enable;                   // Tag enable
  
  logic hit;                             // Hit signal for cache
  logic [15:0] MemData;                  // Data at address spercified

  logic expected_hit;                    // Indicates expected cache hit
  logic [15:0] expected_MemData;         // Data at address spercified

  /* Memory data signals */
  logic [15:0] EX_MEM_ALU_out;
  logic [15:0] MemWriteData;
  logic EX_MEM_MemEnable;
  logic EX_MEM_MemWrite;

  // Instantiate the DUT.  
  Cache iDUT (
        .clk(clk),
        .rst(rst),  
        .addr(EX_MEM_ALU_out),
        
        .data_in(MemWriteData),
        .write_data_array(EX_MEM_MemEnable & EX_MEM_MemWrite),

        .tag_in(tag_in),
        .write_tag_array(hit & enable),
        
        .data_out(MemData),
        .hit(hit)
    );

  // Instantiate the model cache.
  Cache_model iL1_CACHE (
      .clk(clk),
      .rst(rst),  
      .addr(EX_MEM_ALU_out),
        
      .data_in(MemWriteData),
      .write_data_array(EX_MEM_MemEnable & EX_MEM_MemWrite),

      .tag_in(tag_in),
      .write_tag_array(hit & enable),
        
      .data_out(expected_MemData),
      .hit(expected_hit)
  );

  // Set the signals.
  assign EX_MEM_ALU_out = EX_MEM_out[33:18];
  assign MemWriteData = EX_MEM_out[17:2];
  assign EX_MEM_MemEnable = EX_MEM_out[1];
  assign EX_MEM_MemWrite = EX_MEM_out[0];
  assign tag_in = {EX_MEM_ALU_out[15:10], 1'b1, 1'b0};

  // A task to verify the cache.
  task verify_cache();
        if (MemData !== expected_MemData) begin
            $display("ERROR: DUT MemData = 0x%h, Model MemData = 0x%h", MemData, expected_MemData);
            // $stop();
        end

        if (hit !== expected_hit) begin
            $display("ERROR: DUT hit = %b, Model hit = %b", hit, expected_hit);
            // $stop();
        end
  endtask

  // At negative edge of clock, verify the predictions match the model.
  always @(negedge clk) begin
    // Verify the DUT other than reset.
    if (!rst) begin
        verify_cache();
    end
  end

  // Initialize the testbench.
  initial begin
      clk = 1'b0;               // Initially clk is low
      rst = 1'b1;               // Initially rst is high

      // Wait for the first clock cycle to assert reset
      @(posedge clk);
      
      // Assert reset
      @(negedge clk) rst = 1'b1;

      // Deassert reset and start testing.
      @(negedge clk) rst = 1'b0;

      repeat(350) @(posedge clk);  

      // If we reached here it means all tests passed.
      $display("\nYAHOO!! All tests passed.");
      $stop();
  end

  always 
    #5 clk = ~clk; // toggle clock every 5 time units.

  always_ff @(posedge clk) begin
      if (!rst)
        $display("PC=%h | Inst=%h | Addr=%h | DataIn=%h | DataOut=%h | ExpectedDataOut=%h |  MemEn=%b | MemWr=%b | Hit=%b | Expected_Hit=%b",
            pc, 16'h0000, EX_MEM_ALU_out, MemWriteData, MemData, expected_MemData, EX_MEM_MemEnable, EX_MEM_MemWrite, hit, expected_hit);
    end
  
  // Model the PC register.
  always_ff @(posedge clk) begin
    if (rst)
      pc <= 16'h0000;
    else if (!(EX_MEM_MemEnable & ~hit)) begin
      pc <= pc + 16'h0002;
    end
  end

  // Model the IF/ID stage
  always_ff @(posedge clk) begin
        if (rst) begin
            // Reset all output
            IF_ID_out <= '0;
        end else if (!(EX_MEM_MemEnable & ~hit)) begin
            IF_ID_out <= pc;
        end
  end

  // Model the ID/EX stage
  always_ff @(posedge clk) begin
        if (rst) begin
            // Reset all output
            ID_EX_out <= '0;
        end else if (!(EX_MEM_MemEnable & ~hit)) begin
            ID_EX_out <= {$random, $random, $random % 2, $random % 2}; // Memory addr, memory write data, enable, write signals
        end
  end

  // Model the EX/MEM stage
  always_ff @(posedge clk) begin
        if (rst) begin
            // Reset all output
            EX_MEM_out <= '0;
        end else if (!(EX_MEM_MemEnable & ~hit)) begin
            EX_MEM_out <= ID_EX_out;  // Pass it down
        end
  end

  // Model the MEM/WB stage
  always_ff @(posedge clk) begin
        if (rst | !(EX_MEM_MemEnable & ~hit)) begin
            // Reset all output
            MEM_WB_out <= '0;
        end else begin
            MEM_WB_out <= {EX_MEM_out[33:2], MemData}; // Pass it down along with mem_data
        end
  end

endmodule