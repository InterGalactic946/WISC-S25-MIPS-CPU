////////////////////////////////////////////////////////////////////
// memory_system_tb.sv: Testbench for the on-chip memory_system.  //
// Verifies functionality by comparing outputs with a scoreboard  //
// class.                                                         //
////////////////////////////////////////////////////////////////////

module memory_system_tb();

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

  logic ICACHE_proceed;                  // Proceed ICACHE to main mem
  logic [15:0] pc;                       // Current PC value
  logic [15:0] I_MEM_addr;               // Addess of the ICACHE memory section
  logic ICACHE_busy;                     // CPU stall signal for ICACHE
  logic [15:0] PC_inst;                  // Instruction at pc address
  logic ICACHE_hit;                      // Indicates ICACHE hit

  logic DCACHE_proceed;                  // Proceed ICACHE to main mem
  logic [15:0] D_MEM_addr;               // Addess of the DCACHE memory section
  logic DCACHE_busy;                     // CPU stall signal for DCACHE
  logic [15:0] MemData;                  // Data at address spercified
  logic DCACHE_hit;                      // Indicates DCACHE hit

  // Memory data signals
  logic [15:0] EX_MEM_ALU_out;
  logic [15:0] MemWriteData;
  logic EX_MEM_MemEnable;
  logic EX_MEM_MemWrite;


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
      
      .fsm_busy(ICACHE_busy),

      .data_out(PC_inst),
      .hit(ICACHE_hit)
  );

  // Instantiate data memory cache along with control.
  memory_system_model iDATA_MEM_CACHE (
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

      .fsm_busy(DCACHE_busy),
      
      .data_out(MemData),
      .hit(DCACHE_hit)
  );

  // Set the signals.
  assign EX_MEM_ALU_out = EX_MEM_out[33:18];
  assign MemWriteData = EX_MEM_out[17:2];
  assign EX_MEM_MemEnable = EX_MEM_out[1];
  assign EX_MEM_MemWrite = EX_MEM_out[0];

 /* Model the memory */
  memory iMAIN_MEM (
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
  // We grant priority to the ICACHE on a miss when both caches may miss on same cycle.
  assign ICACHE_proceed = ICACHE_busy;
  assign DCACHE_proceed = ~ICACHE_busy & DCACHE_busy;

  // We send out the main memory address as from the instruction cache or data cache based on which is granted.
  assign mem_addr = (ICACHE_proceed) ? I_MEM_addr :
                    (DCACHE_proceed) ? D_MEM_addr :
                    16'h0000;

  // The data output to be written to main memory is only from the DCACHE.
  assign mem_data_out = MemWriteData;

  // We enable main memory either on a cache miss (when either caches are allowed to proceed) or on a DCACHE write.
  assign mem_en = (ICACHE_proceed | DCACHE_proceed) | (DCACHE_hit & EX_MEM_MemWrite & EX_MEM_MemEnable);

  // We write to main memory on a DCACHE write hit as it is a write through cache.
  assign mem_wr = (DCACHE_hit & EX_MEM_MemWrite & EX_MEM_MemEnable);
  /////////////////////////////////////////////////////////////

  // Initialize the testbench.
  initial begin
      clk = 1'b0;               // Initially clk is low
      rst = 1'b1;               // Initially rst is high

      // Wait for the first clock cycle to assert reset
      @(posedge clk);
      
      // Assert reset
      repeat(2) @(negedge clk) rst = 1'b1;

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
        $display("PC=%h | Inst=%h | IHit=%b | Addr=%h | DataIn=%h | MemEn=%b | MemWr=%b | DHit=%b",
            pc, PC_inst, ICACHE_hit, EX_MEM_ALU_out, MemWriteData, EX_MEM_MemEnable, EX_MEM_MemWrite, DCACHE_hit);
    end
  
  // Model the PC register.
  always_ff @(posedge clk) begin
    if (rst)
      pc <= 16'h0000;
    else if (!ICACHE_busy && !DCACHE_busy) begin
      pc <= pc + 16'h0002;
    end
  end

  // Model the IF/ID stage
  always_ff @(posedge clk) begin
        if (rst | ICACHE_busy) begin
            // Reset all output
            IF_ID_out <= '0;
        end else if (!DCACHE_busy) begin
            IF_ID_out <= {pc, PC_inst};
        end
  end

  // Model the ID/EX stage
  always_ff @(posedge clk) begin
        if (rst) begin
            // Reset all output
            ID_EX_out <= '0;
        end else if (!DCACHE_busy) begin
            ID_EX_out <= {$random, $random, $random % 2, $random % 2}; // Memory addr, memory write data, enable, write signals
        end
  end

  // Model the EX/MEM stage
  always_ff @(posedge clk) begin
        if (rst) begin
            // Reset all output
            EX_MEM_out <= '0;
        end else if (!DCACHE_busy) begin
            EX_MEM_out <= ID_EX_out;  // Pass it down
        end
  end

  // Model the MEM/WB stage
  always_ff @(posedge clk) begin
        if (rst | DCACHE_busy) begin
            // Reset all output
            MEM_WB_out <= '0;
        end else begin
            MEM_WB_out <= {EX_MEM_out[33:2], MemData}; // Pass it down along with mem_data
        end
  end

endmodule