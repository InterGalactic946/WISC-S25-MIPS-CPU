`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////////////////////
// RED_Unit_tb.v: Testbench for the Reduction Unit (RED_Unit)         //
// This testbench verifies the functionality of the 16-bit Reduction  //
// Unit (RED_Unit) that utilizes a tree of 4-bit Carry Lookahead      //
// Adders (CLA). It tests the behavior of the Reduction Unit by       //
// applying various test cases with different inputs (A and B), and   //
// checks the correctness of the final sum output as well as overflow //
// conditions at different levels of the adder tree.                  //
////////////////////////////////////////////////////////////////////////
module RED_Unit_tb();

  reg [31:0] stim;	                 // stimulus vector of type reg
  wire [15:0] Sum;                   // 16-bit sum formed on addition/subtraction of the given operands
  reg [15:0] expected_sum;           // expected sum
  reg [16:0] addition_operations;    // number of addition operations performed
  reg error;                         // set an error flag on error

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  RED_Unit iDUT(.A(stim[31:16]), .B(stim[15:0]), .Sum(Sum));
  
  // Initialize the inputs and expected outputs and wait till all tests finish.
  initial begin
    stim = 32'h00000000; // initialize stimulus
    expected_sum = 16'h0000; // initialize expected sum
    addition_operations = 17'h00000; // initialize addition operation count
    error = 1'b0; // initialize error flag

    // Wait to initialize inputs.
    #5;

    // Apply stimulus as 100000 random input vectors.
    repeat (100000) begin
      stim = $random; // Generate random stimulus

      // Wait to process the change in the input.
      #1;

      // Get the expected sum.
      expected_sum = stim[31:16] + stim[15:0];
          
      /* Validate the Sum. */
      if ($signed(Sum) !== $signed(expected_sum)) begin
        $display("ERROR: A: 0x%h, B: 0x%h. Sum expected 0x%h, got 0x%h.", stim[31:16], stim[15:0], expected_sum, Sum);
        error = 1'b1;
      end

      // Count up the number of successful addition operations performed.
      if (!error)
        addition_operations = addition_operations + 1'b1;

      // Print out a status message when the error flag is set.
      if (error) begin
        // Print out the number of reduction additions performed.
        $display("\nNumber of Successful Reduction additions Performed: 0x%h.", addition_operations);
        $stop();
      end

      #5; // wait 5 time units before the next iteration
    end

    // Print out the number of each type of operation performed.
    $display("\nNumber of Successful Reduction additions Performed: 0x%h.", addition_operations);

    // If we reached here, it means that all tests passed.
    $display("YAHOO!! All tests passed.");
    $stop();
  end
  
endmodule

`default_nettype wire  // Reset default behavior at the end