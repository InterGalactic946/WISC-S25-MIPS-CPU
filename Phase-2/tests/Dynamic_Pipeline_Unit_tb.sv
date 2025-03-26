module Dynamic_Pipeline_Unit_tb();

  reg clk, rst;
  reg PC_stall, IF_ID_stall, IF_flush;
  string fetch_msg, decode_msg, execute_msg, memory_msg, wb_msg, instruction_full_msg;

  // Instantiate the DUT
  Dynamic_Pipeline_Unit uut (
      .clk(clk),
      .rst(rst),
      .PC_stall(PC_stall),
      .IF_ID_stall(IF_ID_stall),
      .IF_flush(IF_flush),
      .fetch_msg(fetch_msg),
      .decode_msg(decode_msg),
      .execute_msg(execute_msg),
      .memory_msg(memory_msg),
      .wb_msg(wb_msg),
      .instruction_full_msg(instruction_full_msg)
  );

  // Clock generation
  always #5 clk = ~clk;

  // Task to return fetch message
  task automatic fetch();
    fetch_msg = $sformatf("FETCH_%0t", $time);
  endtask

  // Task to return decode message + full instruction message
  task automatic decode();
    decode_msg = $sformatf("DECODE_%0t", $time);
    instruction_full_msg = $sformatf("INST_FULL_%0t", $time);
  endtask

  // Task to return execute message
  task automatic execute();
    execute_msg = $sformatf("EXECUTE_%0t", $time);
  endtask

  // Task to return memory message
  task automatic memory();
    memory_msg = $sformatf("MEMORY_%0t", $time);
  endtask

  // Task to return write-back message
  task automatic write_back();
    wb_msg = $sformatf("WB_%0t", $time);
  endtask

  // Task to execute all pipeline stages every cycle
  task automatic fdxmw();
    begin
      fetch();
      decode();
      execute();
      memory();
      write_back();
    end
  endtask

  initial begin
    // Initialize signals
    clk = 0;
    rst = 1;
    PC_stall = 0;
    IF_ID_stall = 0;
    IF_flush = 0;

    // Reset cycle
    @(posedge clk);
    rst = 0;

    // Running pipeline normally for a few cycles
    repeat (5) begin
      @(posedge clk);
      fdxmw();
    end

    // Apply stalls and flushes dynamically
    @(posedge clk);
    PC_stall = 1;  // Stall fetch stage
    fdxmw();

    @(posedge clk);
    PC_stall = 0;
    IF_ID_stall = 1;  // Stall decode stage
    fdxmw();

    @(posedge clk);
    IF_ID_stall = 0;
    IF_flush = 1;  // Flush decode stage
    decode_msg = "FLUSHED";
    instruction_full_msg = "FLUSHED";
    fdxmw();

    @(posedge clk);
    IF_flush = 0;
    fdxmw();

    // Continue normal execution
    repeat (5) begin
      @(posedge clk);
      fdxmw();
    end

    // End simulation
    repeat (5) @(posedge clk);
    $finish;
  end

endmodule
