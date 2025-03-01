module cpu_tb();

  import tb_tasks::*;

  ///////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  reg clk, rst_n;

  ///////////////////////////////////
  // Declare internal signals //
  /////////////////////////////////
  wire hlt;
  wire [15:0] pc;
  wire [31:0] instr;
  wire [31:0] regfile [0:31];  // Register file to verify during execution
  logic [31:0] memory [0:1023]; // Memory to be loaded

  // Instantiate DUT
  cpu iDUT(
    .clk(clk), 
    .rst_n(rst_n), 
    .hlt(hlt), 
    .pc(pc)
  );

  // Task to initialize the testbench.
  task automatic Setup();
    begin
      // Initialize all signals for the testbench.
      Initialize(.clk(clk), .rst_n(rst_n));

      // Load instructions into memory for the CPU to execute
      LoadImage("instructions.img", memory);

      // Initialize the PC to a starting value (e.g., 0)
      $display("Initializing CPU Testbench...");
    end
  endtask

  // Test procedure to apply stimulus and check responses
  initial begin
    ///////////////////////////////
    // Initialize the testbench //
    /////////////////////////////
    Setup();
    
    // Run the instruction cycle for multiple instructions
    // Fetch, Decode, Execute, Memory, and Write-Back
    repeat(5) begin
      FetchStage(.pc(pc), .instr(instr), .memory(memory));
      DecodeStage(.instr(instr));
      ExecuteStage(.instr(instr));
      MemoryStage(.instr(instr));
      WriteBackStage(.instr(instr));
    end

    // If the HLT instruction is encountered, stop the simulation
    if (hlt) begin
      $display("HLT instruction encountered. Stopping simulation.");
      $stop();
    end

    // If we reached here, that means all test cases were successful
    $display("YAHOO!! All tests passed.");
    $stop();
  end

  // Generate clock signal with 10 ns period
  always #5 clk = ~clk;

endmodule
