`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////////////////
// CLA_4bit_tb.v: Testbench for the 4-bit adder/subtractor           //
// This testbench verifies the functionality of the 4-bit Carry      //
// Lookahead Adder/Subtractor (CLA_4bit) by applying various test    //
// cases and checking the outputs for both addition and subtraction  //
///////////////////////////////////////////////////////////////////////
module CLA_4bit_tb();

  reg [8:0] stim;	                   // stimulus vector of type reg
  wire [3:0] Sum;                    // 4-bit sum formed on addition/subtraction of the given operands
  wire pos_overflow, neg_overflow;	 // overflow indicator of the addition/subtraction
  reg expected_pos_overflow;         // expected positive overflow
  reg expected_neg_overflow;         // expected negative overflow
  reg [3:0] expected_sum;            // expected sum
  reg [16:0] addition_operations;    // number of addition operations performed
  reg [16:0] subtraction_operations; // number of subtraction operations performed
  reg error;                         // set an error flag on error

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  CLA_4bit iDUT(.A(stim[8:5]),.B(stim[4:1]),.sub(stim[0]), .Cin(1'b0), .Sum(Sum), .pos_Ovfl(pos_overflow), .neg_Ovfl(neg_overflow));
  
  // Initialize the inputs and expected outputs and wait till all tests finish.
  initial begin
    stim = 9'h000; // initialize stimulus
    expected_sum = 4'h0; // initialize expected sum
    expected_pos_overflow = 1'b0; // initialize expected positive overflow
    expected_neg_overflow = 1'b0; // initialize expected negative overflow
    addition_operations = 17'h00000; // initialize addition operation count
    subtraction_operations = 17'h00000; // initialize subtraction operation count
    error = 1'b0; // initialize error flag

    // Wait to initialize inputs.
    #5;

    // Apply stimulus as 100000 random input vectors.
    repeat (100000) begin
      stim = $random & 9'h1FF; // Generate random stimulus

      // Wait to process the change in the input.
      #1;

      // Overflow detection based on operation type.
      case (stim[0])
        1'b0: begin 
          expected_sum = stim[8:5] + stim[4:1];
          
          // Overflow occurs in addition when both operands have the same sign and the result has a different sign.
          if (~stim[8] & ~stim[4]) begin
            // Case when both operands have the same sign (positive)
            if (expected_sum[3] !== stim[8]) begin
                expected_pos_overflow = 1'b1; // Positive overflow detected
                expected_neg_overflow = 1'b0; // No Negative overflow
            end
          end else if (stim[8] & stim[4]) begin
            // Case when both operands have the same sign (negative)
            if (expected_sum[3] !== stim[8]) begin
                expected_neg_overflow = 1'b1; // Negative overflow detected
                expected_pos_overflow = 1'b0; // No Positive overflow
            end
          end else begin
            // Case when operands have different signs (no overflow)
            expected_pos_overflow = 1'b0; // No overflow
            expected_neg_overflow = 1'b0; // No overflow
          end

          /* Validate the Sum. */
          if ($signed(Sum) !== $signed(expected_sum)) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: ADD. Sum expected 0x%h, got 0x%h.", stim[8:5], stim[4:1], expected_sum, Sum);
            error = 1'b1;
          end

          /* Validate the overflow. */
          if (pos_overflow !== expected_pos_overflow) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: ADD. Positve Overflow expected 0x%h, got 0x%h.", stim[8:5], stim[4:1], expected_pos_overflow, pos_overflow);
            error = 1'b1;
          end

          if (neg_overflow !== expected_neg_overflow) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: ADD. Negative Overflow expected 0x%h, got 0x%h.", stim[8:5], stim[4:1], expected_neg_overflow, neg_overflow);
            error = 1'b1;
          end

          // Count up the number of successful addition operations performed.
          if (!error)
            addition_operations = addition_operations + 1'b1;
        end 
        1'b1: begin
          expected_sum = stim[8:5] - stim[4:1];

          // Overflow occurs in subtraction when:
          // 1. A is positive and B is negative but the result is negative.
          // 2. A is negative and B is positive but the result is positive.
          if ((stim[8] === 1'b0) && (stim[4] === 1'b1) && (expected_sum[3] === 1'b1)) begin
              expected_pos_overflow = 1'b1;  // Positive overflow detected (positive - negative giving positive result)
              expected_neg_overflow = 1'b0;  // No negative overflow
          end else if ((stim[8] === 1'b1) && (stim[4] === 1'b0) && (expected_sum[3] === 1'b0)) begin
              expected_neg_overflow = 1'b1;  // Negative overflow detected (negative - positive giving negative result)
              expected_pos_overflow = 1'b0;  // No positive overflow
          end else begin
              expected_pos_overflow = 1'b0;  // No positive overflow
              expected_neg_overflow = 1'b0;  // No negative overflow
          end
          
          /* Validate the Sum. */
          if ($signed(Sum) !== $signed(expected_sum)) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: SUB. Sum expected 0x%h, got 0x%h.", stim[8:5], stim[4:1], expected_sum, Sum);
            error = 1'b1;
          end

          /* Validate the overflow. */
          if (pos_overflow !== expected_pos_overflow) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: SUB. Positve Overflow expected 0x%h, got 0x%h.", stim[8:5], stim[4:1], expected_pos_overflow, pos_overflow);
            error = 1'b1;
          end

          if (neg_overflow !== expected_neg_overflow) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: SUB. Negative Overflow expected 0x%h, got 0x%h.", stim[8:5], stim[4:1], expected_neg_overflow, neg_overflow);
            error = 1'b1;
          end

          // Count up the number of successful subtraction operations performed.
          if (!error)
            subtraction_operations = subtraction_operations + 1'b1;
        end
        default: begin 
          // When the stimulus vector bits are x's or z's we assert an error condition.
          $display("ERROR: The stimulus vector is not compliant with the operation: 0x%h.", stim); 
          error = 1'b1;
        end
      endcase

      // Print out a status message when the error flag is set.
      if (error) begin
        // Print out the number of each type of operation performed.
        $display("\nTotal operations performed: 0x%h.", addition_operations + subtraction_operations);
        $display("Number of Successful Additions Performed: 0x%h.", addition_operations);
        $display("Number of Successful Subtractions Performed: 0x%h.", subtraction_operations);
        $stop();
      end

      #5; // wait 5 time units before the next iteration
    end

    // Print out the number of each type of operation performed.
    $display("\nTotal operations performed: 0x%h.", addition_operations + subtraction_operations);
    $display("Number of Successful Additions Performed: 0x%h.", addition_operations);
    $display("Number of Successful Subtractions Performed: 0x%h.", subtraction_operations);

    // If we reached here, it means that all tests passed.
    $display("YAHOO!! All tests passed.");
    $stop();
  end
  
endmodule

`default_nettype wire  // Reset default behavior at the end