`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////////////////
// ALU_tb.v: Testbench for the 4-bit ALU                       //
// This testbench verifies the functionality of the 4-bit     //
// ALU by applying random stimulus to the inputs and         //
// monitoring the outputs.                                  //               
/////////////////////////////////////////////////////////////
module ALU_tb();

  reg [9:0] stim;    		            // stimulus vector of type reg
  wire [3:0] result; 		            // 4-bit result of the ALU
  wire overflow;     		            // overflow indicator of the ALU
  reg expected_overflow; 	          // expected overflow
  reg [3:0] expected_result;        // expected result
  reg [16:0] addition_operations;    // number of addition operations performed
  reg [16:0] subtraction_operations; // number of subtraction operations performed
  reg [16:0] nand_operations;        // number of nand operations performed
  reg [16:0] xor_operations;         // number of xor operations performed
  reg error;                        // set an error flag on error
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  ALU iDUT(.ALU_In1(stim[9:6]),.ALU_In2(stim[5:2]),.Opcode(stim[1:0]),.ALU_Out(result),.Error(overflow));

  // Initialize the inputs and expected outputs and wait till all tests finish.
  initial begin
    stim = 10'h000; // Initialize stimulus
    expected_result = 4'h0; // initialize expected result
    expected_overflow = 1'b0; // initialize expected overflow
    addition_operations = 17'h00000; // initialize addition operation count
    subtraction_operations = 17'h00000; // initialize subtraction operation count
    nand_operations = 17'h00000; // initialize nand operation count
    xor_operations = 17'h00000; // initialize xor operation count
    error = 1'b0; // initialize error flag

    // Wait to process the change in the input.
    #5;

    // Apply stimulus as 100000 random input vectors.
    repeat (100000) begin
      stim = $random & 10'h3FF; // Generate random stimulus

      // Wait to process the change in the input.
      #5;

      // Perform the operation based on the opcode
      case(stim[1:0])
        2'h0: begin 
          expected_result = stim[9:6] + stim[5:2];

          // Overflow occurs in addition when both operands have the same sign and the result has a different sign.
          if (stim[9] === stim[5]) begin
            if (expected_result[3] !== stim[9]) 
              expected_overflow = 1'b1; // Overflow detected
            else 
              expected_overflow = 1'b0; // No overflow
          end else begin
            expected_overflow = 1'b0; // No overflow when operands have different signs
          end

          // Validate that the result is the expected result.
          if ($signed(result) !== $signed(expected_result)) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: ADD. Sum expected 0x%h, got 0x%h.", stim[9:6], stim[5:2], expected_result, result);
            error = 1'b1;
          end

          // Verify that the overflow indicator is working correctly.
          if (overflow !== expected_overflow) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: ADD. Overflow expected 0x%h, got 0x%h.", stim[9:6], stim[5:2], expected_overflow, overflow);
            error = 1'b1;
          end

          // Count up the number of successful addition operations performed.
          if (!error)
            addition_operations = addition_operations + 1'b1; 
        end
        2'h1: begin
          expected_result = stim[9:6] - stim[5:2];

          // Overflow occurs in subtraction when:
          // 1. A is positive and B is negative, but the result is negative.
          // 2. A is negative and B is positive but the result is positive.
          if ((stim[9] === 1'b0) && (stim[5] === 1'b1) && (expected_result[3] === 1'b1)) 
            expected_overflow = 1'b1; // Overflow detected (positive - negative giving negative)
          else if ((stim[9] === 1'b1) && (stim[5] === 1'b0) && (expected_result[3] == 1'b0)) 
            expected_overflow = 1'b1; // Overflow detected (negative - positive giving positive)
          else 
            expected_overflow = 1'b0; // No overflow in other cases

          // Validate that the result is the expected result.
          if ($signed(result) !== $signed(expected_result)) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: SUB. Sum expected 0x%h, got 0x%h.", stim[9:6], stim[5:2], expected_result, result);
            error = 1'b1;
          end

          // Verify that the overflow indicator is working correctly.
          if (overflow !== expected_overflow) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: SUB. Overflow expected 0x%h, got 0x%h.", stim[9:6], stim[5:2], expected_overflow, overflow);
            error = 1'b1;
          end

          // Count up the number of successful subtraction operations performed.
          if (!error)
            subtraction_operations = subtraction_operations + 1'b1;
        end
        2'h2: begin
          expected_result = ~(stim[9:6] & stim[5:2]);

          // There should not be overflow here.
          expected_overflow = 1'b0;

          // Validate that the result is the expected result.
          if (result !== expected_result) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: NAND. Result expected 0x%h, got 0x%h.", stim[9:6], stim[5:2], expected_result, result);
            error = 1'b1;
          end

          // Verify that the overflow indicator is working correctly.
          if (overflow !== expected_overflow) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: NAND. Overflow expected 0x%h, got 0x%h.", stim[9:6], stim[5:2], expected_overflow, overflow);
            error = 1'b1;
          end

          // Count up the number of successful NAND operations performed.
          if (!error)
            nand_operations = nand_operations + 1'b1;
        end   
        2'h3: begin
          expected_result = stim[9:6] ^ stim[5:2];

          // There should not be overflow here.
          expected_overflow = 1'b0;

          // Validate that the result is the expected result.
          if (result !== expected_result) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: XOR. Result expected 0x%h, got 0x%h.", stim[9:6], stim[5:2], expected_result, result);
            error = 1'b1;
          end

          // Verify that the overflow indicator is working correctly.
          if (overflow !== expected_overflow) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: XOR. Overflow expected 0x%h, got 0x%h.", stim[9:6], stim[5:2], expected_overflow, overflow);
            error = 1'b1;
          end

          // Count up the number of successful XOR operations performed.
          if (!error)
            xor_operations = xor_operations + 1'b1;
        end
        default: begin
          // When the stimulus vector bits are x's or z's we assert an error condition.
          $display("ERROR: The stimulus vector is not compliant with the opcode: 0x%h.", stim); 
          error = 1'b1;
        end
      endcase

      // Print out a status message when the error flag is set.
      if (error) begin
        // Print out the number of each type of operation performed.
        $display("\nTotal operations performed: 0x%h.", addition_operations + subtraction_operations + nand_operations + xor_operations);
        $display("Number of Successful Additions Performed: 0x%h.", addition_operations);
        $display("Number of Successful Subtractions Performed: 0x%h.", subtraction_operations);
        $display("Number of Successful NANDs Performed: 0x%h.", nand_operations);
        $display("Number of Successful XORs Performed: 0x%h.", xor_operations);
        $stop();
      end

      #5; // wait 5 time units before the next iteration
    end

    // Print out the number of each type of operation performed.
    $display("\nTotal operations performed: 0x%h.", addition_operations + subtraction_operations + nand_operations + xor_operations);
    $display("Number of Successful Additions Performed: 0x%h.", addition_operations);
    $display("Number of Successful Subtractions Performed: 0x%h.", subtraction_operations);
    $display("Number of Successful NANDs Performed: 0x%h.", nand_operations);
    $display("Number of Successful XORs Performed: 0x%h.", xor_operations);

    // If we reached here, it means that all tests passed.
    $display("YAHOO!! All tests passed.");
    $stop();
  end

endmodule

`default_nettype wire // Reset default behavior at the end