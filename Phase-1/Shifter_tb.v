`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////////
// Shifter_tb.sv: Testbench for the 16-bit Shifter        //
//                                                        //
// This testbench simulates the shifter for multiple      //
// 16-bit quantities and various shift amounts, testing   //
// both logical and arithmetic shifts.                    //
////////////////////////////////////////////////////////////
module Shifter_tb();

  reg [20:0] stim;    		    // stimulus vector of type reg
  wire [15:0] result;         // result of the shift operation
  reg [15:0] expected_result; // expected result that we should receive from the DUT
  reg [16:0] asr_operations;   // number of asr operations performed
  reg [16:0] sll_operations;   // number of sll operations performed
  reg error;                  // set an error flag on error

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  Shifter iDUT(.Shift_In(stim[15:0]), .Mode(stim[20]), .Shift_Val(stim[19:16]), .Shift_Out(result));
  
  // Test the shifter by performing random logical and arithmetic shifts of various bit widths.
  initial begin
    stim = 21'h000000; // Initialize stimulus
    expected_result = 16'h0000; // initialize expected result
    asr_operations = 17'h00000; // initialize asr operation count
    sll_operations = 17'h00000; // initialize sll operation count
    error = 1'b0; // initialize error flag

    // Wait to process the change in the input.
    #5;

    // Apply stimulus as 100000 random input vectors.
    repeat (100000) begin
      stim = $random & 21'h1FFFFF; // Generate random stimulus

      // Wait to process the change in the input.
      #5;

      // Get the correct expected result based on the mode.
      case(stim[20])
        1'b0: begin 
          expected_result = stim[15:0] << stim[19:16]; // logical shift left
          if(result !== expected_result) begin
            $display("ERROR: Shift_In: 0x%h, Shift_Val: 0x%h, Mode: SLL. Expectd shifted result was: 0x%h, but actual was: 0x%h.", stim[15:0], stim[19:16], expected_result, result);
            error = 1'b1;
          end

          // Count up the number of successful asr operations performed.
          if (!error)
            asr_operations = asr_operations + 1'b1; 
        end
        1'b1: begin
          expected_result = $signed(stim[15:0]) >>> stim[19:16]; // arithmetic right shift
          // Validate that the result is the expected result.
          if($signed(result) !== $signed(expected_result)) begin
            $display("ERROR: Shift_In: 0x%h, Shift_Val: 0x%h, Mode: ASR. Expected shifted result was: 0x%h, but actual was: 0x%h.", stim[15:0], stim[19:16], expected_result, result);
            error = 1'b1;
          end

          // Count up the number of successful sll operations performed.
          if (!error)
            sll_operations = sll_operations + 1'b1; 
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
        $display("\nTotal operations performed: 0x%h.", asr_operations + sll_operations);
        $display("Number of Successful ASRs Performed: 0x%h.", asr_operations);
        $display("Number of Successful SLLs Performed: 0x%h.", sll_operations);
        $stop();
      end

      #5; // wait 5 time units before the next iteration
    end

  // Print out the number of each type of operation performed.
  $display("\nTotal operations performed: 0x%h.", asr_operations + sll_operations);
  $display("Number of Successful ASRs Performed: 0x%h.", asr_operations);
  $display("Number of Successful SLLs Performed: 0x%h.", sll_operations);
  
	// If we reached here, that means all test cases were successful.
	$display("YAHOO!! All tests passed.");
	$stop();
end

endmodule

`default_nettype wire  // Reset default behavior at the end