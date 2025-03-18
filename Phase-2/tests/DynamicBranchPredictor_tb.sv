///////////////////////////////////////////////////////////////////////
// DynamicBranchPredictor_tb.v: Testbench for the Dynamic Branch     //
// Predictor module with BHT and BTB. This testbench verifies the    //
// functionality of the branch predictor by applying various test    //
// cases and checking the outputs, including both correct and        //
// mispredicted branch predictions, by comparing against a model DBP //
///////////////////////////////////////////////////////////////////////

module DynamicBranchPredictor_tb();

  logic clk;                              // Clock signal
  logic rst;                              // Reset signal
  logic enable;                           // Enable signal for the branch predictor
  logic was_branch;                       // Flag to indicate if the current instruction was a branch
  logic actual_taken;                     // Flag indicating whether the branch was actually taken
  logic [15:0] actual_target;             // Actual target address of the branch
  logic IF_ID_predicted_taken;            // Pipelined predicted branch taken signal passed to the decode stage
  logic branch_mispredicted;              // Output indicating if the branch was mispredicted
  reg [3:0] PC_curr;                      // Current PC value
  reg [3:0] IF_ID_PC_curr;                // IF/ID stage current PC value

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

  // Task to apply controlled test cases and verify that the predictor adapts over time.
  task automatic apply_controlled_test_cases();
    begin
      integer i;
      // Repeat the test case multiple times to check if the predictor learns.
      for (i = 0; i < 5; i = i + 1) begin

        // Wait for changes to settle at the next positive clock edge.
        @(posedge clk);

        // Set initial PC where the branch occurs.
        PC_curr = 4'h2;

        #1; // small delay

        // Check if the branch prediction matches the expected behavior.
        if (predicted_taken !== expected_predicted_taken) begin
          $display("ERROR: Iteration %0d | PC=0x%h | predicted_taken=0b%b | expected_predicted_taken=0b%b.", 
                  i, PC_curr, predicted_taken, expected_predicted_taken);
          $stop();
        end

        if (predicted_target !== expected_predicted_target) begin
          $display("ERROR: Iteration %0d | PC=0x%h | predicted_target=0x%h | expected_predicted_target=0x%h.", 
                  i, PC_curr, predicted_target, expected_predicted_target);
          $stop();
        end

        // Wait for changes to settle at the next positive clock edge.
        @(posedge clk);

        // Apply actual branch outcomes at the next negative clock edge.
        @(negedge clk) begin
          was_branch   = 1'b1;                 // Indicate that a branch was encountered.
          actual_taken = (i >= 2) ? 1'b1 : 1'b0; // Initially not taken, then taken after 2 iterations.
          actual_target = 16'h0040;            // Set actual branch target (arbitrary value).
          
          // The number of times we mispredicted the branch.
          if ((((was_branch && !actual_taken) && IF_ID_predicted_taken)) || ((was_branch && actual_taken) && !IF_ID_predicted_taken)) begin
              misprediction_count = misprediction_count + 1; // Increment misprediction counter.
              branch_mispredicted = 1'b1;
          end else begin
              branch_mispredicted = 1'b0;
          end
        end

        // Display the final prediction results for debugging.
        $display("Iteration %0d | PC=0x%h | Predicted Taken: %b | Predicted Target: 0x%h | Expected Taken: %b | Expected Target: 0x%h", 
                i, PC_curr, predicted_taken, predicted_target, expected_predicted_taken, expected_predicted_target);
      end
    end
  endtask


  // Task to apply random stimulus for each input of the DUT.
  task automatic apply_random_stimulus(input integer num_tests);
    integer i;

    // Apply num_tests of stimulus.
    for (i = 0; i < num_tests; i = i + 1) begin

      // Wait for a clock cycle to allow processing
      @(posedge clk);

      // The number of times we actually took the branch.
      if (was_branch && actual_taken)
        actual_taken_count = actual_taken_count + 1;
        
      // The number of times we mispredicted the branch.
      if ((((was_branch && !actual_taken) && IF_ID_predicted_taken)) || ((was_branch && actual_taken) && !IF_ID_predicted_taken)) begin
          misprediction_count = misprediction_count + 1;
      end
        
      // The number of times we predicted we took the branch.
      if (IF_ID_predicted_taken === 1'b1)
        predicted_taken_count = predicted_taken_count + 1;
        
      // The number of times we predicted we did not take the branch.
      if (IF_ID_predicted_taken === 1'b0)
        predicted_not_taken_count = predicted_not_taken_count + 1;
      
      PC_curr = $random % 4;    // Random 4-bit PC address
      
      #1; // small delay

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

      // Apply stimulus on negative edge.
      @(negedge clk) begin;
        // Generate random values for all inputs
        enable         = $random % 2;    // Random enable (0 or 1)
        was_branch     = $random % 2;    // Random branch indication (0 or 1)
        actual_taken   = $random % 2;    // Random actual branch outcome (0 or 1)
        actual_target  = $random;        // Random 16-bit target address
        
        // The number of times we mispredicted the branch.
        if ((((was_branch && !actual_taken) && IF_ID_predicted_taken)) || ((was_branch && actual_taken) && !IF_ID_predicted_taken))
            branch_mispredicted = 1'b1;
        else
            branch_mispredicted = 1'b0;
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
    branch_mispredicted = 1'b0; // Initially branch is not mispredicted
    PC_curr = 4'h0;   // Start with PC = 0
    IF_ID_PC_curr = 4'h0; // Start with PC = 0
    IF_ID_predicted_taken = 1'b0; // The prediction is initially not wrong.
    
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

    // Models the active clock edge the DUT just fetched the instruction.
    @(posedge clk);
    
    // Go with PC = 0x8. (Branch instruction)
    PC_curr = 4'h8; // Branch not taken
    
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

    // We're at the beginging of the decode stage.
    @(posedge clk);

    // We learned that the branch was actually taken.
    @(negedge clk) begin;
      was_branch = 1'b1;
      actual_taken = 1'b1;
      actual_target = 16'h0080;
      branch_mispredicted = 1'b1;
    end

    // Models the active clock edge the DUT just fetched the next instruction.
    @(posedge clk);
    
    // Go with PC = 0xA. (Non Branch instruction)
    PC_curr = 4'hA;
    
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

    // Deasssert signals
    @(negedge clk) begin;
      was_branch = 1'b0;
      actual_taken = 1'b0;
      actual_target = 16'h0000;
      branch_mispredicted = 1'b0;
    end

    // We're at the beginging of the decode stage.
    @(posedge clk);

    // We set the signals.
    @(negedge clk) begin;
      was_branch = 1'b0;
      actual_taken = 1'b0;
      actual_target = 16'h0040; // Doesn't matter
      branch_mispredicted = 1'b0;
    end

    // Models the active clock edge the DUT just fetched the next instruction.
    @(posedge clk);
    
    // Go with PC = 0x8. (Branch instruction)
    PC_curr = 4'h8; // Should still predict not taken
    
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

    // Deasssert signals
    @(negedge clk) begin;
      was_branch = 1'b0;
      actual_taken = 1'b0;
      actual_target = 16'h0000;
      branch_mispredicted = 1'b0;
    end
    
    // Models the active clock edge the DUT just fetched the next instruction.
    @(posedge clk);

    // We learned that the branch was actually taken.
    @(negedge clk) begin;
      was_branch = 1'b1;
      actual_taken = 1'b1;
      actual_target = 16'h0080;
      branch_mispredicted = 1'b1;
    end

    // Models the active clock edge the DUT just fetched the next instruction.
    @(posedge clk);
    
    // Go with PC = 0x8. (Branch instruction)
    PC_curr = 4'h8; // Should predict taken
    
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

    // Deasssert signals
    @(negedge clk) begin;
      was_branch = 1'b0;
      actual_taken = 1'b0;
      actual_target = 16'h0000;
      branch_mispredicted = 1'b0;
    end

    $display("PC_curr=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b.",PC_curr, predicted_taken, expected_predicted_taken);
    $display("PC_curr=0x%h, predicted_target=0x%h, expected_predicted_target=0x%h.", PC_curr, predicted_target, expected_predicted_target);
    
    // // Apply controlled test cases before random stimulus.
    // apply_controlled_test_cases();

    // // Apply randomized test cases.
    // apply_random_stimulus(.num_tests(1000000));

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
  
  // Model the predict_taken register.
  always @(posedge clk)
    if (rst)
      IF_ID_predicted_taken <= 1'b0;
    else
      IF_ID_predicted_taken <= expected_predicted_taken;

endmodule