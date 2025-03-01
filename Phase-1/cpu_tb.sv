`default_nettype none // Set the default as none to avoid errors

module cpu_tb();

  import tb_tasks::*;

  ///////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  reg clk, rst_n;

  ///////////////////////////////
  // Declare internal signals //
  /////////////////////////////
  wire hlt;
  wire [15:0] pc;
  wire [15:0] instr;
  wire [15:0] regfile [0:15];         // Register file to verify during execution
  logic [15:0] instr_memory [0:1023]; // Instruction Memory to be loaded
  logic [15:0] instr_memory [0:1023]; // Data Memory to be loaded

   //////////////////////
  // Instantiate DUT //
  ////////////////////
  cpu iDUT(.clk(clk), .rst_n(rst_n), .hlt(hlt), .pc(pc));

  // Task to initialize the testbench.
  task automatic Setup();
    begin
      // Initialize all signals for the testbench.
      Initialize(.clk(clk), .rst_n(rst_n));

      // Load instructions into memory for the CPU to execute
      LoadImage("instructions.img", instr_memory);

      // Load instructions into data memory for the CPU to perform memory operations
      LoadImage("data.img", data_memory);

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
      FetchInstruction(.pc(pc), .instr(instr), .memory(memory));
      DecodeInstruction(.instr(instr));
      ExecuteInstruction(.instr(instr));
      MemoryInstruction(.instr(instr));
      WriteBackInstruction(.instr(instr));
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

`default_nettype wire  // Reset default behavior at the end
