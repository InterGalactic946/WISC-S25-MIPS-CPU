module dynamic_pipeline_tb();

  reg clk, rst;
  reg PC_stall, IF_ID_stall, IF_flush;
  string fetch_msg, decode_msg, execute_msg, memory_msg, wb_msg, instruction_full_msg;

  // Instantiate the DUT
  dynamic_pipeline uut (
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
      .instruction_full_msg(instruction_full_msg),
  );

  // Clock generation
  always #5 clk = ~clk; // 10-time unit period

  initial begin
    // Initialize signals
    clk = 0;
    rst = 1;
    PC_stall = 0;
    IF_ID_stall = 0;
    IF_flush = 0;
    fetch_msg = "";
    decode_msg = "";
    execute_msg = "";
    memory_msg = "";
    wb_msg = "";
    instruction_full_msg = "";

    // Reset cycle
    @(posedge clk);
    rst = 0;

    // Apply first instruction (without stalls)
    @(posedge clk);
    fetch_msg = "FETCH_1";
    instruction_full_msg = "INST_1";

    @(posedge clk);
    decode_msg = "DECODE_1";

    @(posedge clk);
    execute_msg = "EXECUTE_1";

    @(posedge clk);
    memory_msg = "MEMORY_1";

    @(posedge clk);
    wb_msg = "WB_1";

    // Apply stalls during the second instruction
    @(posedge clk);
    fetch_msg = "FETCH_2";
    instruction_full_msg = "INST_2";
    PC_stall = 1; // Stall fetch stage

    @(posedge clk);
    PC_stall = 0;
    decode_msg = "DECODE_2";
    IF_ID_stall = 1; // Stall decode stage

    @(posedge clk);
    IF_ID_stall = 0;
    execute_msg = "EXECUTE_2";

    @(posedge clk);
    memory_msg = "MEMORY_2";

    @(posedge clk);
    wb_msg = "WB_2";

    // Apply flush condition on the third instruction
    @(posedge clk);
    fetch_msg = "FETCH_3";
    instruction_full_msg = "INST_3";
    IF_flush = 1; // Flush instruction in decode

    @(posedge clk);
    IF_flush = 0;

    // Continue normal pipeline operation
    @(posedge clk);
    decode_msg = "DECODE_3";

    @(posedge clk);
    execute_msg = "EXECUTE_3";

    @(posedge clk);
    memory_msg = "MEMORY_3";

    @(posedge clk);
    wb_msg = "WB_3";

    // End simulation
    repeat (5) @(posedge clk);
    $finish;
  end

endmodule
