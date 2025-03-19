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
  logic [1:0] IF_ID_prediction;           // Pipelined predicted signal passed to the decode stage
  logic branch_mispredicted;              // Output indicating if the branch was mispredicted
  reg [3:0] PC_curr;                      // Current PC value
  reg [3:0] IF_ID_PC_curr;                // IF/ID stage current PC value

  integer actual_taken_count;           // Number of times branch was actually taken.
  integer predicted_taken_count;        // Number of times branch was predicted to be taken.
  integer predicted_not_taken_count;    // Number of times branch was predicted to not be taken.
  integer misprediction_count;          // Number of times branch was mispredicted.
  wire [1:0] prediction;                // The 2-bit predicted taken flag from the predictor
  wire [15:0] predicted_target;         // The predicted target address from the predictor
  wire [1:0] expected_prediction;       // The expected prediction from the model DBP
  wire [15:0] expected_predicted_target;// The expected predicted target address from from the model DBP

  // Instantiate the DUT: Dynamic Branch Predictor.
  DynamicBranchPredictor iDUT (
    .clk(clk), 
    .rst(rst), 
    .PC_curr(PC_curr), 
    .IF_ID_PC_curr(IF_ID_PC_curr), 
    .IF_ID_prediction(IF_ID_prediction), 
    .enable(enable),
    .was_branch(was_branch),
    .actual_taken(actual_taken),
    .actual_target(actual_target),  
    .branch_mispredicted(branch_mispredicted), 
    
    .prediction(prediction), 
    .predicted_target(predicted_target)
  );

  // Instantiate the model dynamic branch predictor.
  DynamicBranchPredictor_model iDBP_model (
    .clk(clk), 
    .rst(rst), 
    .PC_curr(PC_curr), 
    .IF_ID_PC_curr(IF_ID_PC_curr), 
    .IF_ID_prediction(IF_ID_prediction), 
    .enable(enable),
    .was_branch(was_branch),
    .actual_taken(actual_taken),
    .actual_target(actual_target),  
    .branch_mispredicted(branch_mispredicted), 
    
    .prediction(expected_prediction), 
    .predicted_target(expected_predicted_target)
  );


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
    IF_ID_prediction = 2'b00; // The prediction is initially not wrong.
    
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
      if (prediction !== expected_prediction) begin
        $display("ERROR: PC_curr=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b.",PC_curr, prediction[1], expected_prediction[1]);
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
    
    // Verify the prediction.
    if (prediction !== expected_prediction) begin
      $display("ERROR: PC_curr=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b.",PC_curr, prediction[1], expected_prediction[1]);
      $stop();
    end

    // Verify the predicted target.
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
    
    // Verify the prediction.
    if (prediction !== expected_prediction) begin
      $display("ERROR: PC_curr=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b.",PC_curr, prediction[1], expected_prediction[1]);
      $stop();
    end

    // Verify the predicted target.
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
    
    // Verify the prediction.
    if (prediction !== expected_prediction) begin
      $display("ERROR: PC_curr=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b.",PC_curr, prediction[1], expected_prediction[1]);
      $stop();
    end

    // Verify the predicted target.
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
    
    // Verify the prediction.
    if (prediction !== expected_prediction) begin
      $display("ERROR: PC_curr=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b.",PC_curr, prediction[1], expected_prediction[1]);
      $stop();
    end

    // Verify the predicted target.
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

    $display("PC_curr=0x%h, predictedion=0b%b, expected_prediction=0b%b.",PC_curr, prediction, expected_prediction);
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
  
  // Model the prediction register.
  always @(posedge clk)
    if (rst)
      IF_ID_prediction <= 2'b00;
    else
      IF_ID_prediction <= expected_prediction;

endmodule