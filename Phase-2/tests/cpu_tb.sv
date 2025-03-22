///////////////////////////////////////////////////////////
// cpu_tb.sv: CPU Testbench Module                       //  
//                                                       //
// This module serves as the testbench for the CPU core. //
// It verifies the correct functionality of instruction  //
// fetching, decoding, execution, and memory operations. //
// The testbench initializes memory, loads instructions, //
// and monitors register updates and ALU results. It     //
// also checks branching behavior and halting conditions.//
///////////////////////////////////////////////////////////
module cpu_tb();

  import ALU_tasks::*;
  import Model_tasks::*;
  import Verification_tasks::*;

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  cpu iDUT (.clk(clk), .rst_n(rst_n), .hlt(hlt), .pc(pc));

  ////////////////////////
  // Instantiate Model //
  //////////////////////
  cpu_model iMODEL (.clk(clk), .rst_n(rst_n), .hlt(expected_hlt), .pc(expected_pc));

  ///////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  logic clk, rst_n;          // clock and rst signals
  logic hlt, expected_hlt;   // Halt signals for execution stop for each DUT and model
  logic [15:0] expected_pc;  // Expected program counter value for verification
  logic [15:0] pc;           // Current program counter value

  // Test procedure to apply stimulus and check responses.
  initial begin
    // Initialize the testbench.
    Initialize(.clk(clk), .rst_n(rst_n));

    // Run the simulation for each instruction in the instruction memory.
    repeat (100) @(posedge clk);

    // If we reached here, that means all test cases were successful
    $display("YAHOO!! All tests passed.");
    $stop();
  end
  
  // Verify the flag register at the begining of each clock cycle.
  always @(posedge clk) begin
    // Ignore the check on reset.
    if (rst_n) begin
      // Print out the current state of the model's flag register.
      $display("Model flag register state: ZF = 0b%1b, VF = 0b%1b, NF = 0b%1b.", flag_reg[2], flag_reg[1], flag_reg[0]);
      
      // Verify the DUT's flag register at the begining of each cycle.
      VerifyFlagRegister(.flag_reg(flag_reg), .DUT_flag_reg({iDUT.ZF, iDUT.VF, iDUT.NF}), .error(error));
    end
  end

  // Generate clock signal with 10 ns period.
  always 
    #5 clk = ~clk;

endmodule

`default_nettype wire  // Reset default behavior at the end
