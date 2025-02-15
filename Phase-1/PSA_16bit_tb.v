`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////////////////////
// PSA_16bit_tb.v: Testbench for the 16-bit Parallel Adder         //
//                                                                 //
// This testbench verifies the functionality of the 16-bit         //
// parallel adder by applying random stimulus to the               //
// inputs and monitoring the corresponding outputs.                //
// It ensures that the adder operations work as expected for       //
// each of the 4-bit sub-words across different input              //
// combinations and edge cases.                       .            //
/////////////////////////////////////////////////////////////////////
module PSA_16bit_tb();

  reg [31:0] stim;	               // stimulus vector of type reg
  wire [15:0] Sum;                 // 16-bit sum formed on addition of the given operands
  wire overflow;	                 // error indicator of the addition
  reg [3:0] expected_overflow;     // stores expected overflow of each sub word addition
  reg [3:0] expected_sum[0:3];     // expected sum, an array of 4, 4-bit vectors
  reg [16:0] addition_operations;  // number of addition operations performed
  reg error;                       // set an error flag on error

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  PSA_16bit iDUT(.A(stim[31:16]),.B(stim[15:0]),.Sum(Sum),.Error(overflow));
  
  // Initialize the inputs and expected outputs and wait till all tests finish.
  initial begin
    stim = 32'h00000000; // initialize stimulus
    expected_sum[0] = 4'h0; // LSN (Least-Significant Nibble)
    expected_sum[1] = 4'h0; // LSMN (Least-Significant Middle Nibble)
    expected_sum[2] = 4'h0; // MSMN (Most-Significant Middle Nibble)
    expected_sum[3] = 4'h0; // MSN (Most-Significant Nibble)
    expected_overflow = 4'h0; // initialize expected overflow
    addition_operations = 17'h00000; // initialize addition operation count
    error = 1'b0; // initialize error flag

    // Wait to initialize inputs.
    #5;

    // Apply stimulus as 100000 random input vectors.
    repeat (100000) begin
      stim = $random; // Generate random stimulus

      // Wait to process the change in the input.
      #5;

      // Get the expected sum.
      expected_sum[3] = stim[31:28] + stim[15:12];
      expected_sum[2] = stim[27:24] + stim[11:8];
      expected_sum[1] = stim[23:20] + stim[7:4];
      expected_sum[0] = stim[19:16] + stim[3:0];

      /* Overflow occurs in addition when both operands have the same sign and the result has a different sign. */

      // Form the MSN's expected overflow.
      if (stim[31] === stim[15]) begin
        if (expected_sum[3][3] !== stim[31])
          expected_overflow[3] = 1'b1; // Overflow detected
        else
          expected_overflow[3] = 1'b0; // No overflow
      end else begin 
        expected_overflow[3] = 1'b0; // No overflow when operands have different signs
      end

      // Form the MSMN's expected overflow.
      if (stim[27] === stim[11]) begin
        if (expected_sum[2][3] !== stim[27])
          expected_overflow[2] = 1'b1; // Overflow detected
        else
          expected_overflow[2] = 1'b0; // No overflow
      end else begin 
        expected_overflow[2] = 1'b0; // No overflow when operands have different signs
      end

      // Form the LSMN's expected overflow.
      if (stim[23] === stim[7]) begin
        if (expected_sum[1][3] !== stim[23])
          expected_overflow[1] = 1'b1; // Overflow detected
        else
          expected_overflow[1] = 1'b0; // No overflow
      end else begin 
        expected_overflow[1] = 1'b0; // No overflow when operands have different signs
      end

      // Form the LSN's expected overflow.
      if (stim[19] === stim[3]) begin
        if (expected_sum[0][3] !== stim[19])
          expected_overflow[0] = 1'b1; // Overflow detected
        else
          expected_overflow[0] = 1'b0; // No overflow
      end else begin 
        expected_overflow[0] = 1'b0; // No overflow when operands have different signs
      end

      /* Validate the Sum. */
      if ($signed(Sum) !== $signed({expected_sum[3], expected_sum[2], expected_sum[1], expected_sum[0]})) begin
          $display("ERROR: A: 0x%h, B: 0x%h.\nExpected_Sum[3]: 0x%h, Expected_Sum[2]: 0x%h, Expected_Sum[1]: 0x%h, Expected_Sum[0]: 0x%h.\nSum[3]: 0x%h, Sum[2]: 0x%h, Sum[1]: 0x%h, Sum[0]: 0x%h.", stim[31:16], stim[15:0], expected_sum[3], expected_sum[2], expected_sum[1], expected_sum[0], Sum[15:12], Sum[11:8], Sum[7:4], Sum[3:0]);
          error = 1'b1;
      end

      /* Validate the overflow. */
      if (overflow !== |expected_overflow) begin
        $display("ERROR: A: 0x%h, B: 0x%h.\nExpected_Overflow[3]: 0x%h, Expected_Overflow[2]: 0x%h, Expected_Overflow[1]: 0x%h, Expected_Overflow[0]: 0x%h.\nOverflow[3]: 0x%h, Overflow[2]: 0x%h, Overflow[1]: 0x%h, Overflow[0]: 0x%h.", stim[31:16], stim[15:0], expected_overflow[3], expected_overflow[2], expected_overflow[1], expected_overflow[0], iDUT.Overflow[3], iDUT.Overflow[2], iDUT.Overflow[1], iDUT.Overflow[0]);
        error = 1'b1;
      end

      // Count up the number of successful addition operations performed.
      if (!error)
        addition_operations = addition_operations + 1'b1; 

      // Print out a status message when the error flag is set.
      if (error) begin
        // Print out the number of oprations performed.
        $display("\nNumber of Successful Additions Performed: 0x%h.", addition_operations);
        $stop();
      end

      #5; // wait 5 time units before the next iteration
    end

    // Print out the number of each type of operation performed.
    $display("\nNumber of Successful Additions Performed: 0x%h.", addition_operations);

    // If we reached here, it means that all tests passed.
    $display("YAHOO!! All tests passed.");
    $stop();
  end
  
endmodule

`default_nettype wire  // Reset default behavior at the end