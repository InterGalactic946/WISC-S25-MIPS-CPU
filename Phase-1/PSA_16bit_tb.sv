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
  reg pos_overflow[0:3];           // stores expected positive overflow of each sub word addition
  reg neg_overflow[0:3];           // stores expected negative overflow of each sub word addition
  reg [3:0] expected_sum[0:3];     // expected sum, an array of 4, 4-bit vectors
  reg [15:0] expected_PSA_sum;     // expected PSA_16bit sum
  reg expected_PSA_error;          // the expected error flag of the PSA_16bit operation
  reg [16:0] addition_operations;  // number of addition operations performed
  reg error;                       // set an error flag on error

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  PSA_16bit iDUT(.A(stim[31:16]), .B(stim[15:0]), .Sum(Sum), .Error(overflow));

  // Task 1: Check for positive or negative overflow for each 4-bit sub-word.
  task check_overflow(input [31:0] stimulus);
      // Check overflow for each 4-bit sub-word (nibble)
      // Checking the sum and determining whether the overflow is positive or negative.

      // Check for overflow in the MSB nibble (bits 31:28 and 15:12)
      if (stimulus[31] === stimulus[15]) begin  // Both operands have the same sign
        if (stimulus[31:28] + stimulus[15:12] > 4'd7)
          pos_overflow[3] = 1;  // Positive overflow
        else if (stimulus[31:28] + stimulus[15:12] < -4'h8)
          neg_overflow[3] = 1;  // Negative overflow
        else begin
          pos_overflow[3] = 0;  // No positive overflow
          neg_overflow[3] = 0;  // No negative overflow
        end
      end else begin 
        pos_overflow[3] = 0;  // No overflow when operands have different signs
        neg_overflow[3] = 0;
      end

      // Check for overflow in the second MSB nibble (bits 27:24 and 11:8)
      if (stimulus[27] === stimulus[11]) begin
        if (stimulus[27:24] + stimulus[11:8] > 4'd7)
          pos_overflow[2] = 1;  // Positive overflow
        else if (stimulus[27:24] + stimulus[11:8] < -4'd8)
          neg_overflow[2] = 1;  // Negative overflow
        else begin
          pos_overflow[2] = 0;  // No positive overflow
          neg_overflow[2] = 0;  // No negative overflow
        end
      end else begin 
        pos_overflow[2] = 0;  // No overflow when operands have different signs
        neg_overflow[2] = 0;
      end

      // Check for overflow in the second LSB nibble (bits 23:20 and 7:4)
      if (stimulus[23] === stimulus[7]) begin
        if (stimulus[23:20] + stimulus[7:4] > 4'd7)
          pos_overflow[1] = 1;  // Positive overflow
        else if (stimulus[23:20] + stimulus[7:4] < -4'h8)
          neg_overflow[1] = 1;  // Negative overflow
        else begin
          pos_overflow[1] = 0;  // No positive overflow
          neg_overflow[1] = 0;  // No negative overflow
        end
      end else begin 
        pos_overflow[1] = 0;  // No overflow when operands have different signs
        neg_overflow[1] = 0;
      end

      // Check for overflow in the LSB nibble (bits 19:16 and 3:0)
      if (stimulus[19] === stimulus[3]) begin  // Both operands have the same sign
          if (stimulus[19:16] + stimulus[3:0] > 4'd7)
              pos_overflow[0] = 1;  // Positive overflow
          else if (stimulus[19:16] + stimulus[3:0] < -4'd8)
              neg_overflow[0] = 1;  // Negative overflow
          else begin
              pos_overflow[0] = 0;  // No positive overflow
              neg_overflow[0] = 0;  // No negative overflow
          end
      end else begin 
          pos_overflow[0] = 0;  // No overflow when operands have different signs
          neg_overflow[0] = 0;
      end

      // Get the expected error flag.
      expected_PSA_error = (pos_overflow[3] | pos_overflow[2] | pos_overflow[1] | pos_overflow[0]) | 
                     (neg_overflow[3] | neg_overflow[2] | neg_overflow[1] | neg_overflow[0]);
  endtask

  // Task 2: Apply saturation based on overflow flags for each 4-bit sub-word (nibble).
  task apply_saturation();
      // Apply saturation based on the overflow flags for each nibble in the expected_sum array

      // Handle Most Significant Nibble (MSN)
      if (pos_overflow[3] === 1) begin
          expected_sum[3] = 4'h7;  // Saturate to max positive value for most significant nibble
      end else if (neg_overflow[3] === 1) begin
          expected_sum[3] = 4'h8;  // Saturate to max negative value for most significant nibble
      end else begin
          expected_sum[3] = stim[31:28] + stim[15:12];  // No overflow, use the actual sum
      end

      // Handle second Most Significant Nibble (MSMN)
      if (pos_overflow[2] === 1) begin
          expected_sum[2] = 4'h7;  // Saturate to max positive value for second most significant nibble
      end else if (neg_overflow[2] === 1) begin
          expected_sum[2] = 4'h8;  // Saturate to max negative value for second most significant nibble
      end else begin
          expected_sum[2] = stim[27:24] + stim[11:8];  // No overflow, use the actual sum
      end

      // Handle second Least Significant Nibble (LSMN)
      if (pos_overflow[1] === 1) begin
          expected_sum[1] = 4'h7;  // Saturate to max positive value for second least significant nibble
      end else if (neg_overflow[1] === 1) begin
          expected_sum[1] = 4'h8;  // Saturate to max negative value for second least significant nibble
      end else begin
          expected_sum[1] = stim[23:20] + stim[7:4];  // No overflow, use the actual sum
      end

      // Handle Least Significant Nibble (LSN)
      if (pos_overflow[0] === 1) begin
          expected_sum[0] = 4'h7;  // Saturate to max positive value for least significant nibble
      end else if (neg_overflow[0] === 1) begin
          expected_sum[0] = 4'h8;  // Saturate to max negative value for least significant nibble
      end else begin
          expected_sum[0] = stim[19:16] + stim[3:0];  // No overflow, use the actual sum
      end
      
      // Form the expected_PSA_sum.
      expected_PSA_sum = {expected_sum[3], expected_sum[2], expected_sum[1], expected_sum[0]};
  endtask

  
  // Initialize the inputs and expected outputs and wait till all tests finish.
  initial begin
    stim = 32'h00000000; // initialize stimulus
    expected_sum = '{default: 4'h0}; // initialize the expected sum array
    expected_PSA_sum = 16'h0000; // initialize expected PSA_16bit sum
    expected_PSA_error = 1'b0; // initialize expected error flag
    pos_overflow = '{default: 4'h0}; // initialize expected pos overflow
    neg_overflow = '{default: 4'h0}; // initialize expected neg overflow
    addition_operations = 17'h00000; // initialize addition operation count
    error = 1'b0; // initialize error flag

    // Wait to initialize inputs.
    #5;

    // Apply stimulus as 100000 random input vectors.
    repeat (100000) begin
      stim = $random; // Generate random stimulus

      // Wait to process the change in the input.
      #1;

      // Get the overflow of the sum.
      check_overflow(.stimulus(stim));

      // Form the expected sum.
      apply_saturation();

      /* Validate the Sum. */
      if ($signed(Sum) !== $signed(expected_PSA_sum)) begin
          $display("\nERROR: Expected sum does not match the received sum. A: 0x%h, B: 0x%h.\nExpected_Sum[3]: 0x%h, Expected_Sum[2]: 0x%h, Expected_Sum[1]: 0x%h, Expected_Sum[0]: 0x%h.\nSum[3]: 0x%h, Sum[2]: 0x%h, Sum[1]: 0x%h, Sum[0]: 0x%h.", stim[31:16], stim[15:0], expected_sum[3], expected_sum[2], expected_sum[1], expected_sum[0], Sum[15:12], Sum[11:8], Sum[7:4], Sum[3:0]);
          error = 1'b1;
      end

      /* Validate the overflow. */
      if (overflow !== expected_PSA_error) begin
        $display("\nERROR: Error flag does not match expected error flag. A: 0x%h, B: 0x%h.\nExpected_Pos_Ovfl[3]: 0x%h, Expected_Pos_Ovfl[2]: 0x%h, Expected_Pos_Ovfl[1]: 0x%h, Expected_Pos_Ovfl[0]: 0x%h.\nExpected_Neg_Ovfl[3]: 0x%h, Expected_Neg_Ovfl[2]: 0x%h, Expected_Neg_Ovfl[1]: 0x%h, Expected_Neg_Ovfl[0]: 0x%h.\nDUT_Pos_Ovfl[3]: 0x%h, DUT_Pos_Ovfl[2]: 0x%h, DUT_Pos_Ovfl[1]: 0x%h, DUT_Pos_Ovfl[0]: 0x%h.\nDUT_Neg_Ovfl[3]: 0x%h, DUT_Neg_Ovfl[2]: 0x%h, DUT_Neg_Ovfl[1]: 0x%h, DUT_Neg_Ovfl[0]: 0x%h.", 
            stim[31:16], stim[15:0], 
            pos_overflow[3], pos_overflow[2], pos_overflow[1], pos_overflow[0], 
            neg_overflow[3], neg_overflow[2], neg_overflow[1], neg_overflow[0], 
            iDUT.pos_Ovfl[3], iDUT.pos_Ovfl[2], iDUT.pos_Ovfl[1], iDUT.pos_Ovfl[0], 
            iDUT.neg_Ovfl[3], iDUT.neg_Ovfl[2], iDUT.neg_Ovfl[1], iDUT.neg_Ovfl[0]);
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