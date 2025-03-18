`default_nettype none // Set the default as none to avoid errors 

///////////////////////////////////////////////////////////////////////
// DynamicBranchPredictor_tb.v: Testbench for the Dynamic Branch     //
// Predictor module with BHT and BTB. This testbench verifies the    //
// functionality of the branch predictor by applying various test    //
// cases and checking the outputs, including both correct and        //
// mispredicted branch predictions, by comparing against a model DBP //
///////////////////////////////////////////////////////////////////////

module DynamicBranchPredictor_tb();

  reg clk;                              // Clock signal
  reg rst;                              // Reset signal
  reg enable;                           // Enable signal for the branch predictor
  reg was_branch;                       // Flag to indicate if the current instruction was a branch
  reg actual_taken;                     // Flag indicating whether the branch was actually taken
  reg [15:0] actual_target;             // Actual target address of the branch
  reg branch_mispredicted;              // Output indicating if the branch was mispredicted
  reg [3:0] PC_curr;                    // Current PC value
  reg [3:0] IF_ID_PC_curr;              // IF/ID stage current PC value

  integer actual_taken_count;           // Number of times branch was actually taken.
  integer predicted_taken_count;        // Number of times branch was predicted to be taken.
  integer predicted_not_taken_count;    // Number of times branch was predicted to not be taken.
  integer misprediction_count;          // Number of times branch was mispredicted.
  wire predicted_taken;                 // The predicted taken flag from the predictor
  wire [15:0] predicted_target;         // The predicted target address from the predictor
  wire expected_predicted_taken;        // The expected predicted taken flag from the model DBP
  wire [15:0] expected_predicted_target;// The expected predicted target address from from the model DBP

  // Instantiate the DUT: Dynamic Branch Predictor.
  DynamicBranchPredictor iDUT (
    .clk(clk), 
    .rst(rst), 
    .PC_curr(PC_curr), 
    .IF_ID_PC_curr(IF_ID_PC_curr), 
    .enable(enable),
    .was_branch(was_branch),
    .actual_taken(actual_taken),
    .actual_target(actual_target),
    .branch_mispredicted(branch_mispredicted),
    .predicted_taken(predicted_taken),
    .predicted_target(predicted_target)
  );

  // Instantiate the model dynamic branch predictor.
  DynamicBranchPredictor_model iDBP_model (
    .clk(clk), 
    .rst(rst), 
    .PC_curr(PC_curr), 
    .IF_ID_PC_curr(IF_ID_PC_curr), 
    .enable(enable),
    .was_branch(was_branch),
    .actual_taken(actual_taken),
    .actual_target(actual_target),  
    .branch_mispredicted(branch_mispredicted), 
    .predicted_taken(expected_predicted_taken), 
    .predicted_target(expected_predicted_target)
  );

  // Task to apply controlled test cases before random stimulus.
  task automatic apply_controlled_test_cases();
    begin
      // First branch at PC = 2, not taken initially
      @(negedge clk);
      PC_curr = 4'h2;
      was_branch = 1'b1;
      actual_taken = 1'b0;
      actual_target = 16'h0040;
      
      // Wait to settle.
      @(posedge clk);

      // Check on negedge.
      @(negedge clk) begin
        // Debugging: print out the predictor state and transition for first branch
        $display("Predictor State at PC=0x%h: predicted_taken=%0b, predicted_target=%0h", PC_curr, predicted_taken, predicted_target);
        $display("Actual Taken: %0b, Actual Target: %0h", actual_taken, actual_target);
        
        // Verify if the prediction is correct after the first cycle
        if (predicted_taken !== expected_predicted_taken) begin
          $display("ERROR: PC=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b.", PC_curr, predicted_taken, expected_predicted_taken);
          $stop();
        end
        if (predicted_target !== expected_predicted_target) begin
          $display("ERROR: PC=0x%h, predicted_target=0x%h, expected_predicted_target=0x%h.", PC_curr, predicted_target, expected_predicted_target);
          $stop();
        end
      end

      $display("Predicted taken: %0d, Predicted target: %0d, Expected Predicted taken: %0d, Expected Predicted target: %0d.", predicted_taken, predicted_target, expected_predicted_taken, expected_predicted_target);

      // Second branch at PC = 6, taken.
      PC_curr = 4'h6;
      was_branch = 1'b1;
      actual_taken = 1'b1;
      actual_target = 16'h0080;
      
      // Wait to settle.
      @(posedge clk);

      // Check on negedge.
      @(negedge clk) begin
        // Debugging: print out the predictor state and transition for second branch
        $display("Predictor State at PC=0x%h: predicted_taken=%0b, predicted_target=%0h", PC_curr, predicted_taken, predicted_target);
        $display("Actual Taken: %0b, Actual Target: %0h", actual_taken, actual_target);

        // Verify if the prediction is correct after the second cycle
        if (predicted_taken !== expected_predicted_taken) begin
          $display("ERROR: PC=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b.", PC_curr, predicted_taken, expected_predicted_taken);
          $stop();
        end
        if (predicted_target !== expected_predicted_target) begin
          $display("ERROR: PC=0x%h, predicted_target=0x%h, expected_predicted_target=0x%h.", PC_curr, predicted_target, expected_predicted_target);
          $stop();
        end
      end

      $display("Predicted taken: %0d, Predicted target: %0d, Expected Predicted taken: %0d, Expected Predicted target: %0d.", predicted_taken, predicted_target, expected_predicted_taken, expected_predicted_target);

      // Third branch at PC = 10, not taken again
      PC_curr = 4'hA;
      was_branch = 1'b1;
      actual_taken = 1'b0;
      actual_target = 16'h00C0;
      
      // Wait to settle.
      @(posedge clk);

      // Check on negedge.
      @(negedge clk) begin
        // Debugging: print out the predictor state and transition for third branch
        $display("Predictor State at PC=0x%h: predicted_taken=%0b, predicted_target=%0h", PC_curr, predicted_taken, predicted_target);
        $display("Actual Taken: %0b, Actual Target: %0h", actual_taken, actual_target);

        // Verify if the prediction is correct after the third cycle
        if (predicted_taken !== expected_predicted_taken) begin
          $display("ERROR: PC=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b", PC_curr, predicted_taken, expected_predicted_taken);
          $stop();
        end
        if (predicted_target !== expected_predicted_target) begin
          $display("ERROR: PC=0x%h, predicted_target=0x%h, expected_predicted_target=0x%h", PC_curr, predicted_target, expected_predicted_target);
          $stop();
        end
      end

      $display("Predicted taken: %0d, Predicted target: %0d, Expected Predicted taken: %0d, Expected Predicted target: %0d.", predicted_taken, predicted_target, expected_predicted_taken, expected_predicted_target);

      // Fourth branch at PC = 2 again, should be taken now if predictor learned
      PC_curr = 4'h2;
      was_branch = 1'b1;
      actual_taken = 1'b1;
      actual_target = 16'h0040;
      
      // Wait to settle.
      @(posedge clk);

      // Check on negedge.
      @(negedge clk) begin
        // Debugging: print out the predictor state and transition for fourth branch
        $display("Predictor State at PC=0x%h: predicted_taken=%0b, predicted_target=%0h", PC_curr, predicted_taken, predicted_target);
        $display("Actual Taken: %0b, Actual Target: %0h", actual_taken, actual_target);

        // Verify if the prediction is correct after the fourth cycle
        if (predicted_taken !== expected_predicted_taken) begin
          $display("ERROR: PC=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b", PC_curr, predicted_taken, expected_predicted_taken);
          $stop();
        end
        if (predicted_target !== expected_predicted_target) begin
          $display("ERROR: PC=0x%h, predicted_target=0x%h, expected_predicted_target=0x%h", PC_curr, predicted_target, expected_predicted_target);
          $stop();
        end
      end

      $display("Predicted taken: %0d, Predicted target: %0d, Expected Predicted taken: %0d, Expected Predicted target: %0d.", predicted_taken, predicted_target, expected_predicted_taken, expected_predicted_target);

      // Verify if predictor learned to take branch at PC = 2.
      if (predicted_taken !== 1'b1) begin
        $display("ERROR: Predictor did not learn branch at PC=2 should be taken.");
        $stop();
      end else begin
        $display("SUCCESS: Predictor learned branch at PC=2 should be taken.");
        $display("SUCCESS: Predictor learned target branch at PC=2 should should be: 0x%h.", expected_predicted_target);
      end
    end
  endtask

  // Task to apply random stimulus for each input of the DUT.
  task automatic apply_random_stimulus(input integer num_tests);
    integer i;

    // Apply num_tests of stimulus.
    for (i = 0; i < num_tests; i = i + 1) begin
      
      // Apply stimulus on negative edge.
      @(negedge clk) begin;
        // Generate random values for all inputs
        PC_curr        = $random % 4;    // Random 4-bit PC address
        enable         = $random % 2;    // Random enable (0 or 1)
        was_branch     = $random % 2;    // Random branch indication (0 or 1)
        actual_taken   = $random % 2;    // Random actual branch outcome (0 or 1)
        actual_target  = $random;        // Random 16-bit target address
      end

      // Wait for a clock cycle to allow processing
      @(posedge clk);
      
      // Verify the result on a negative edge.
      @(negedge clk) begin
        // Verify the prediction.
        if (predicted_taken !== expected_predicted_taken) begin
          $display("ERROR: PC_curr=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b.",PC_curr, predicted_taken, expected_predicted_taken);
          $stop();
        end

        // Verify the predicted target.
        if (predicted_target !== expected_predicted_target) begin
          $display("ERROR: PC_curr=0x%h, predicted_target=0x%h, expected_predicted_target=0x%h.", PC_curr, predicted_target, expected_predicted_target);
          $stop();
        end

        // The number of times we actually took the branch.
        if (was_branch && actual_taken)
          actual_taken_count = actual_taken_count + 1;
        
        // The number of times we mispredicted the branch.
        if ((((was_branch && !actual_taken) && predicted_taken)) || ((was_branch && actual_taken) && !predicted_taken))
            misprediction_count = misprediction_count + 1;
        
        // The number of times we predicted we took the branch.
        if (predicted_taken === 1'b1)
          predicted_taken_count = predicted_taken_count + 1;
        
        // The number of times we predicted we did not take the branch.
        if (predicted_taken === 1'b0)
          predicted_not_taken_count = predicted_not_taken_count + 1;
      end
    end
  endtask

  // Initialize the testbench.
  initial begin
    clk = 1'b0; // initially clk is low
    rst = 1'b0; // initially rst is low
    enable = 1'b1;  // Enable the branch predictor
    was_branch = 1'b0;    // Initially no branch
    actual_taken = 1'b0;  // Initially the branch is not taken
    actual_target = 16'h0000; // Set target to 0 initially
    PC_curr = 4'h0;   // Start with PC = 0
    IF_ID_PC_curr = 4'h0; // Start with PC = 0
    
    // Initialize counter values.
    actual_taken_count = 0;
    predicted_taken_count = 0;
    predicted_not_taken_count = 0;
    misprediction_count = 0;

    // Wait to initialize inputs.
    repeat(2) @(posedge clk);
    
    // Wait for a negative edge to assert rst.
    @(negedge clk) rst = 1'b1;

    // Wait for a full clock cycle before deasserting rst.
    @(negedge clk) begin
      // Deassert reset.
      rst = 1'b0;

      // Verify the prediction after reset.
      if (predicted_taken !== expected_predicted_taken) begin
        $display("ERROR: PC_curr=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b.",PC_curr, predicted_taken, expected_predicted_taken);
        $stop();
      end

      // Verify the predicted target after reset.
      if (predicted_target !== expected_predicted_target) begin
        $display("ERROR: PC_curr=0x%h, predicted_target=0x%h, expected_predicted_target=0x%h.", PC_curr, predicted_target, expected_predicted_target);
        $stop();
      end
    end

    // Apply controlled test cases before random stimulus.
    apply_controlled_test_cases();

    // Apply randomized test cases.
    apply_random_stimulus(.num_tests(1000000));

    // Print out the count of branches predicted taken and not taken.
    $display("Number of branches predicted to be taken: %0d. Number of branches predicted to be not taken: %0d.", predicted_taken_count, predicted_not_taken_count);

    // Print out the count of mispredictions.
    $display("Number of mispredictions: %0d.", misprediction_count);

    // Print out the count of actual taken branches.
    $display("Number of branches actually taken: %0d.", actual_taken_count);

    // If we reached here, it means that all tests passed.
    $display("YAHOO!! All tests passed.");
    $stop();
  end

  always 
    #5 clk = ~clk; // toggle clock every 5 time units.

  // Model the PC curr register.
  always @(posedge clk)
    if (rst)
      IF_ID_PC_curr <= 4'h0;
    else
      IF_ID_PC_curr <= PC_curr;

endmodule

`default_nettype wire  // Reset default behavior at the end
