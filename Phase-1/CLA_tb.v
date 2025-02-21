`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////////////////////
// CLA_tb.v: Testbench for the 16-bit hierarchical Carry Lookahead //
// Adder (CLA) using 4-bit CLA blocks                              //
// This testbench verifies the functionality of the 16-bit CLA     //
// by applying various test cases for addition and subtraction.    //
// The 16-bit CLA is instantiated by connecting four 4-bit CLA     //
// blocks, and the outputs (Sum and Overflow) are monitored for    //
// correctness.                                                    //
/////////////////////////////////////////////////////////////////////
module CLA_tb();

  reg [32:0] stim;	                 // stimulus vector of type reg
  wire [15:0] Sum;                   // 16-bit sum formed on addition/subtraction of the given operands
  wire overflow;	                   // overflow indicator of the addition/subtraction
  reg expected_overflow;             // expected overflow
  reg [15:0] expected_sum;           // expected sum
  reg [16:0] addition_operations;    // number of addition operations performed
  reg [16:0] subtraction_operations; // number of subtraction operations performed
  reg error;                         // set an error flag on error

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  CLA iDUT(.A(stim[32:17]), .B(stim[16:1]), .sub(stim[0]), .Sum(Sum), .Ovfl(overflow));
  
  // Initialize the inputs and expected outputs and wait till all tests finish.
  initial begin
    stim = 33'h000000000; // initialize stimulus
    expected_sum = 16'h0000; // initialize expected sum
    expected_overflow = 1'b0; // initialize expected overflow
    addition_operations = 17'h00000; // initialize addition operation count
    subtraction_operations = 17'h00000; // initialize subtraction operation count
    error = 1'b0; // initialize error flag

    // Wait to initialize inputs.
    #5;

    // Apply stimulus as 100000 random input vectors.
    repeat (100000) begin
      stim[32:1] = $random; // Generate random stimulus
      stim[0] = $random & 1'b1;

      // Wait to process the change in the input.
      #5;

      // Overflow detection based on operation type.
      case (stim[0])
        1'b0: begin 
          expected_sum = stim[32:17] + stim[16:1];
          
          // Overflow occurs in addition when both operands have the same sign and the result has a different sign.
          if (stim[32] === stim[16]) begin
            if (expected_sum[15] !== stim[32]) 
              expected_overflow = 1'b1; // Overflow detected
            else 
              expected_overflow = 1'b0; // No overflow
          end else begin
            expected_overflow = 1'b0; // No overflow when operands have different signs
          end

          /* Validate the Sum. */
          if ($signed(Sum) !== $signed(expected_sum)) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: ADD. Sum expected 0x%h, got 0x%h.", stim[8:5], stim[4:1], expected_sum, Sum);
            error = 1'b1;
          end

          /* Validate the overflow. */
          if (overflow !== expected_overflow) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: ADD. Overflow expected 0x%h, got 0x%h.", stim[8:5], stim[4:1], expected_overflow, overflow);
            error = 1'b1;
          end

          // Count up the number of successful addition operations performed.
          if (!error)
            addition_operations = addition_operations + 1'b1;
        end 
        1'b1: begin
          expected_sum = stim[32:17] - stim[16:1];

          // Overflow occurs in subtraction when:
          // 1. A is positive and B is negative but the result is negative.
          // 2. A is negative and B is positive but the result is positive.
          if ((stim[32] === 1'b0) && (stim[16] === 1'b1) && (expected_sum[15] === 1'b1))
            expected_overflow = 1'b1; // Overflow detected (positive - negative giving negative)
          else if ((stim[32] === 1'b1) && (stim[16] === 1'b0) && (expected_sum[15] === 1'b0)) 
            expected_overflow = 1'b1; // Overflow detected (negative - positive giving positive)
          else 
            expected_overflow = 1'b0; // No overflow in other cases
          
          /* Validate the Sum. */
          if ($signed(Sum) !== $signed(expected_sum)) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: SUB. Sum expected 0x%h, got 0x%h.", stim[8:5], stim[4:1], expected_sum, Sum);
            error = 1'b1;
          end

          /* Validate the overflow. */
          if (overflow !== expected_overflow) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: SUB. Overflow expected 0x%h, got 0x%h.", stim[8:5], stim[4:1], expected_overflow, overflow);
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