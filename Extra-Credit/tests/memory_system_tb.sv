////////////////////////////////////////////////////////////////////
// memory_system_tb.sv: Testbench for the on-chip memory_system.  //
// Verifies functionality by comparing outputs with a scoreboard  //
// class.                                                         //
////////////////////////////////////////////////////////////////////

module memory_system_tb();

  logic clk;                             // Clock signal
  logic rst;                             // Active high reset 
  integer icache_log, dcache_log;        // Files to write to

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

  logic PC_stall;                        // PC stall signal
  logic IF_ID_stall;                     // IF_ID stall signal
  logic IF_flush;                        // IF flush signal
  logic ID_EX_stall;                     // ID_EX stall signal
  logic EX_MEM_stall;                    // EX_MEM stall signal
  logic MEM_flush;                       // MEM flush signal

  logic [15:0] pc;                       // Current PC value
  logic [15:0] I_MEM_addr;               // Addess of the ICACHE memory section
  logic ICACHE_miss_mem_en;              // Miss memory enable for ICACHE
  logic [15:0] PC_inst;                  // Instruction at pc address
  logic ICACHE_hit;                      // Indicates ICACHE hit

  logic DCACHE_proceed;                  // Proceed DCACHE to main mem
  logic [15:0] D_MEM_addr;               // Addess of the DCACHE memory section
  logic DCACHE_miss_mem_en;              // Miss memory enable for DCACHE
  logic [15:0] MemData;                  // Data at address spercified
  logic DCACHE_hit;                      // Indicates DCACHE hit

  // Memory data signals
  logic [15:0] EX_MEM_ALU_out;
  logic [15:0] MemWriteData;
  logic EX_MEM_MemEnable;
  logic EX_MEM_MemWrite;
  logic [15:0] rand_addr;
  logic [15:0] rand_data;
  logic        rand_en;
  logic        rand_wr;

  // Instantiate the instruction cache along with control.  
  memory_system iINSTR_MEM_CACHE (
      .clk(clk),
      .rst(rst),
      .enable(1'b1),
      .proceed(1'b1),
      .on_chip_wr(1'b0),
      .on_chip_memory_address(pc),
      .on_chip_memory_data(16'h0000),

      .off_chip_memory_data(mem_data_in),
      .memory_data_valid(mem_data_valid),

      .off_chip_memory_address(I_MEM_addr),      
      .miss_mem_en(ICACHE_miss_mem_en),

      .data_out(PC_inst),
      .hit(ICACHE_hit)
  );

  // Instantiate data memory cache along with control.
  memory_system iDATA_MEM_CACHE (
      .clk(clk),
      .rst(rst),
      .enable(EX_MEM_MemEnable),
      .proceed(DCACHE_proceed),
      .on_chip_wr(EX_MEM_MemWrite),
      .on_chip_memory_address(EX_MEM_ALU_out),
      .on_chip_memory_data(MemWriteData),

      .off_chip_memory_data(mem_data_in),
      .memory_data_valid(mem_data_valid),

      .off_chip_memory_address(D_MEM_addr),      
      .miss_mem_en(DCACHE_miss_mem_en),

      .data_out(MemData),
      .hit(DCACHE_hit)
  );

  // Set the DCACHE signals.
  assign EX_MEM_ALU_out = EX_MEM_out[33:18];
  assign MemWriteData = EX_MEM_out[17:2];
  assign EX_MEM_MemEnable = EX_MEM_out[1];
  assign EX_MEM_MemWrite = EX_MEM_out[0];

  /* Model the memory */
  memory4c iMAIN_MEM (
    .clk(clk),
    .rst(rst),
    .enable(mem_en),
    .addr(mem_addr),
    .wr(mem_wr),
    .data_in(mem_data_out),
    
    .data_valid(mem_data_valid),
    .data_out(mem_data_in)
  );

  //////////////////////////////////////////////////////////
  // Arbitrate accesses to data memory between I/D caches //
  //////////////////////////////////////////////////////////
  // We grant priority to the DCACHE only if ICACHE is not a miss as well, i.e., ICACHE_hit, but not DCACHE hit.
  assign DCACHE_proceed = ICACHE_hit & ~DCACHE_hit;

  // We send out the main memory address as from the instruction cache or data cache based on which is granted.
  assign mem_addr = (~ICACHE_hit) ? I_MEM_addr :
                    (~DCACHE_hit) ? D_MEM_addr :
                    16'h0000;

  // The data output to be written to main memory is only from the DCACHE.
  assign mem_data_out = MemWriteData;

  // We enable main memory either on a cache miss (when either caches are allowed to proceed) or on a DCACHE write hit.
  assign mem_en = (~ICACHE_hit) ? ICACHE_miss_mem_en :
                  (~DCACHE_hit) ? DCACHE_miss_mem_en :
                  DCACHE_hit & EX_MEM_MemEnable & EX_MEM_MemWrite;

  // We write to main memory on a DCACHE write hit as it is a write through cache.
  assign mem_wr = DCACHE_hit & EX_MEM_MemEnable & EX_MEM_MemWrite;
  /////////////////////////////////////////////////////////////

  // Initialize the testbench.
  initial begin
      clk = 1'b0;         // Initially clk is low
      rst = 1'b0;         // Initially rst is low
      
      icache_log = $fopen("./tests/output/logs/transcript/icache.log", "w"); // "w" = write (overwrite each run)
      dcache_log = $fopen("./tests/output/logs/transcript/dcache.log", "w");

      if (!icache_log) $fatal("Failed to open icache_log.txt");
      if (!dcache_log) $fatal("Failed to open dcache_log.txt");

      // Wait for the first clock cycle to assert reset
      @(posedge clk);

      // Assert reset
      @(negedge clk) rst = 1'b1;

      // Deassert reset and start testing.
      @(negedge clk) rst = 1'b0;

      repeat(500) @(posedge clk);  

      // If we reached here it means all tests passed.
      $display("\nYAHOO!! All tests passed.");
      $stop();
  end

  always 
    #5 clk = ~clk; // toggle clock every 5 time units.

  // Print out the messages for each cache.
  always_ff @(posedge clk) begin
    if (!rst) begin
      $fdisplay(icache_log, "PC=0x%h | PC_inst=0x%h | I_Hit=%b | ICACHE_Addr=0x%h | MemDataValid=%b | TagArrayWrite=%b | TagIn=0x%h | DataArrayWrite=%b | DataIn=0x%h | Cycle=%0d",
                pc, PC_inst, ICACHE_hit,
                iINSTR_MEM_CACHE.iL1_CACHE.addr,
                mem_data_valid,
                iINSTR_MEM_CACHE.iL1_CACHE.write_tag_array,
                iINSTR_MEM_CACHE.iL1_CACHE.tag_in,
                iINSTR_MEM_CACHE.iL1_CACHE.write_data_array,
                iINSTR_MEM_CACHE.iL1_CACHE.data_in,
                ($time/10));

      $fdisplay(dcache_log, "ADDR=0x%h | MemData=0x%h | MemEnable=%b | MemWrite=%b | D_Hit=%b | DCACHE_Addr=0x%h | MemDataValid=%b | TagArrayWrite=%b | TagIn=0x%h | DataArrayWrite=%b | DataIn=0x%h | Cycle=%0d",
                EX_MEM_ALU_out, MemData, EX_MEM_MemEnable, EX_MEM_MemWrite, DCACHE_hit,
                iDATA_MEM_CACHE.iL1_CACHE.addr,
                mem_data_valid,
                iDATA_MEM_CACHE.iL1_CACHE.write_tag_array,
                iDATA_MEM_CACHE.iL1_CACHE.tag_in,
                iDATA_MEM_CACHE.iL1_CACHE.write_data_array,
                iDATA_MEM_CACHE.iL1_CACHE.data_in,
                ($time/10));
    end
  end
  
  // Model the PC register.
  always_ff @(posedge clk) begin
    if (rst)
      pc <= 16'h0000;
    else if (~PC_stall) begin
      pc <= pc + 16'h0002;
    end
  end

  // We stall on an ICACHE miss or propogated stall from IF_ID.
  assign PC_stall = (!ICACHE_hit) || IF_ID_stall;

  // Send a NOP when ICACHE miss.
  assign IF_flush = !ICACHE_hit;

  // Stall IF_ID on propogated stall.
  assign IF_ID_stall = ID_EX_stall;

  // Model the IF/ID stage
  always_ff @(posedge clk) begin
        if (rst | IF_flush) begin
            // Reset all output
            IF_ID_out <= '0;
        end else if (!IF_ID_stall) begin
            IF_ID_out <= {pc, PC_inst};
        end
  end

  // Stall the ID_EX stage from propgated stall.
  assign ID_EX_stall = EX_MEM_stall;

  // Model the ID/EX stage
  always_ff @(posedge clk) begin
    if (rst) begin
        ID_EX_out <= '0;
    end else if (!ID_EX_stall) begin
        // Ensure rand_addr >= 0x180A by adding offset
        rand_addr = 16'h180A + ($urandom % (16'hFFFF - 16'h180A + 1));
        rand_data = $urandom;
        rand_en   = $urandom % 2;
        rand_wr   = $urandom % 2;

        ID_EX_out <= {rand_addr, rand_data, rand_en, rand_wr};
    end
  end

  // Stall EX_MEM on DCACHE miss when enabled.
  assign EX_MEM_stall = (!DCACHE_hit && EX_MEM_MemEnable);

  // Model the EX/MEM stage
  always_ff @(posedge clk) begin
        if (rst) begin
            // Reset all output
            EX_MEM_out <= '0;
        end else if (!EX_MEM_stall) begin
            EX_MEM_out <= ID_EX_out;  // Pass it down
        end
  end

  // Send a NOP when DCACHE miss.
  assign MEM_flush = (!DCACHE_hit && EX_MEM_MemEnable);

  // Model the MEM/WB stage
  always_ff @(posedge clk) begin
        if (rst | MEM_flush) begin
            // Reset all output
            MEM_WB_out <= '0;
        end else begin
            MEM_WB_out <= {EX_MEM_out[33:2], MemData}; // Pass it down along with mem_data
        end
  end

endmodule