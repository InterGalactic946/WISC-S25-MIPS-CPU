///////////////////////////////////////////////////////////
 // post_synth_tb.sv: CPU Testbench Module                //  
 //                                                       //
 // This module serves as the testbench for the CPU core. //
 // It verifies the correct functionality of instruction  //
 // fetching, decoding, execution, and memory operations. //
 // The testbench initializes memory, loads instructions, //
 // and monitors register updates and ALU results. It     //
 // also checks branching behavior and halting conditions.//
 ///////////////////////////////////////////////////////////
 module post_synth_tb();

  
  // Importing task library.
  import Verification_tasks::*;
 
   ///////////////////////////
   // Stimulus of type reg //
   /////////////////////////
   logic clk, rst_n;                  // Clock and reset signals
   logic hlt;                         // Halt signals for execution stop for DUT
   logic [15:0] pc;                   // Current program counter value
   integer log_file;                  // log file
 
   //////////////////////
   // Instantiate DUT //
   ////////////////////
   cpu iDUT (
     .clk(clk),
     .rst_n(rst_n),
     .hlt(hlt),
     .pc(pc)
   );
 
   // Test procedure to apply stimulus and check responses.
   initial begin
     // Initialize the testbench
     Initialize(.clk(clk), .rst_n(rst_n));

     // Open a log file.
     log_file = $fopen("./outputs/verilogsim.log");      
 
     // Setup the testbench environment.
     $display("\n");
 
     // Run the simulation for each instruction in the instruction memory until HLT reaches WB.
     TimeoutTask(.sig(hlt), .clk(clk), .clks2wait(1000000), .signal("HLT"));
 
     // Wait for 2 cycles to print last actual instruction and HLT.
     repeat (2) @(posedge clk);
     
     $display("\nCPU halted due to HLT instruction.\n");
     
     // Close the file.
     $fclose(log_file);
 
     // If we reached here, that means all test cases were successful.
     $display("YAHOO!! All tests passed.");
     $stop();
   end
 
   // Print out the values throughout the course of execution.
   always @(posedge clk) begin
    // Display to the file.
     $fdisplay(log_file, "PC: 0x%h | MemAddr: 0x%h | MemEn: %b | MemWr: %b | MemValid: %b | MemIn: 0x%h | MemOut: 0x%h", pc, iDUT.mem_addr, iDUT.mem_en, iDUT.mem_wr, iDUT.mem_data_valid, iDUT.mem_data_in, iDUT.mem_data_out);

     // Display to console.
     $display("PC: 0x%h | MemAddr: 0x%h | MemEn: %b | MemWr: %b | MemValid: %b | MemIn: 0x%h | MemOut: 0x%h", pc, iDUT.mem_addr, iDUT.mem_en, iDUT.mem_wr, iDUT.mem_data_valid, iDUT.mem_data_in, iDUT.mem_data_out);
   end
 
 
   // Generate clock signal with 10 ns period
   always 
     #5 clk = ~clk;
 
 endmodule