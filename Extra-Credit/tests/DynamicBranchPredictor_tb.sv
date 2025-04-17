///////////////////////////////////////////////////////////////////////
// DynamicBranchPredictor_tb.v: Testbench for the Dynamic Branch     //
// Predictor module with BHT and BTB. This testbench verifies the    //
// functionality of the branch predictor by applying various test    //
// cases and checking the outputs, including both correct and        //
// mispredicted branch predictions, by comparing against a model DBP //
///////////////////////////////////////////////////////////////////////

import Monitor_tasks::*;

module DynamicBranchPredictor_tb();

  logic clk;                              // Clock signal
  logic rst;                              // Reset signal
  
  logic enable;                           // Enable signal for the branch predictor
  logic wen_BTB;                          // Write enable for BTB (Branch Target Buffer) (from the decode stage)
  logic wen_BHT;                          // Write enable for BHT (Branch History Table) (from the decode stage)
  logic update_PC;                        // Signal to update the PC with the actual target

  logic is_branch;                        // Flag to indicate if the previous instruction was a branch
  
  logic actual_taken;                     // Flag indicating whether the branch was actually taken
  logic [15:0] actual_target;             // Actual target address of the branch
  logic [1:0] IF_ID_prediction;           // Pipelined predicted signal passed to the decode stage
  logic [15:0] IF_ID_predicted_target;    // Predicted target passed to the decode stage
  logic [15:0] PC_curr;                   // Current PC value
  logic [15:0] IF_ID_PC_curr;             // IF/ID stage current PC value

  logic mispredicted;                     // Indicates previous instruction's fetch mispredicted.
  logic target_miscomputed;               // Indicates previous instruction's fetch miscomputed the target.
  logic branch_taken;                     // Indicates branch was actually taken.

  integer actual_taken_count;             // Number of times branch was actually taken.
  integer predicted_taken_count;          // Number of times branch was predicted to be taken.
  integer predicted_not_taken_count;      // Number of times branch was predicted to not be taken.
  integer misprediction_count;            // Number of times branch was mispredicted.
  integer test_counter;                   // Number of tests executed.
  integer stalls;                         // Number of PC stalls.
  integer branch_count;                   // Number of branches executed.
  integer num_tests;                      // Number of test cases to execute.

  wire predicted_taken;                   // The predicted value of the current instruction.
  wire [1:0] prediction;                  // The 2-bit predicted taken flag from the predictor
  wire [15:0] predicted_target;           // The predicted target address from the predictor
  wire expected_predicted_taken;          // The expected predicted taken value from the model DBP
  wire [1:0] expected_prediction;         // The expected prediction from the model DBP
  wire [15:0] expected_predicted_target;  // The expected predicted target address from from the model DBP

  // Instantiate the DUT: Dynamic Branch Predictor.
  DynamicBranchPredictor iDUT (
    .clk(clk), 
    .rst(rst), 
    .PC_curr(PC_curr), 
    .IF_ID_PC_curr(IF_ID_PC_curr), 
    .IF_ID_prediction(IF_ID_prediction), 
    .enable(enable),
    .wen_BTB(wen_BTB),
    .wen_BHT(wen_BHT),
    .actual_taken(actual_taken),
    .actual_target(actual_target),  
    
    .predicted_taken(predicted_taken),
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
    .wen_BTB(wen_BTB),
    .wen_BHT(wen_BHT),
    .actual_taken(actual_taken),
    .actual_target(actual_target),  
    
    .predicted_taken(expected_predicted_taken),
    .prediction(expected_prediction), 
    .predicted_target(expected_predicted_target)
  );

  // A task to verify the prediction and target.
  task verify_prediction_and_target();
    begin
      // Verify the predicted taken value.
      if (predicted_taken !== expected_predicted_taken) begin
        $display("ERROR: PC_curr=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b.", PC_curr, predicted_taken, expected_predicted_taken);
        $stop();
      end

      // Verify the prediction.
      if (prediction !== expected_prediction) begin
        $display("ERROR: PC_curr=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b.", PC_curr, prediction[1], expected_prediction[1]);
        $stop();
      end
      
      // Verify the predicted target.
      if (predicted_target !== expected_predicted_target) begin
        $display("ERROR: PC_curr=0x%h, predicted_target=0x%h, expected_predicted_target=0x%h.", PC_curr, predicted_target, expected_predicted_target);
        $stop();
      end
    end
  endtask

  // At negative edge of clock, verify the predictions match the model.
  always @(negedge clk) begin
    if (!rst) begin
      // Verify the predictions.
      verify_prediction_and_target();

      // Dump the contents of memory whenever we write to the BTB or BHT.
      if (wen_BHT || wen_BTB)
        log_BTB_BHT_dump (
          .model_BHT(iDBP_model.BHT),
          .model_BTB(iDBP_model.BTB)
        );
    end
  end

  // Initialize the testbench.
  initial begin
      clk = 1'b0;              // Initially clk is low
      rst = 1'b0;              // Initially rst is low
      enable = 1'b1;           // Enable the branch predictor
      is_branch = 1'b0;        // Initially no branch
      actual_taken = 1'b0;     // Initially the branch is not taken
      actual_target = 16'h0000; // Set target to 0 initially
      PC_curr = 16'h0000;       // Start with PC = 0
      IF_ID_PC_curr = 4'h0;    // Start with PC = 0
      IF_ID_prediction = 2'b00; // Start with strongly not taken prediction (prediction[1] = 0)

      // Initialize counter values.
      actual_taken_count = 0;
      predicted_taken_count = 0;
      predicted_not_taken_count = 0;
      misprediction_count = 0;
      branch_count = 0;
      test_counter = 0;
      stalls = 0;

      // initialize num_tests.
      num_tests = 30000;

      // Wait for the first clock cycle to assert reset
      @(posedge clk);
      
      // Assert reset
      @(negedge clk) rst = 1'b1;

      // Deassert reset and start testing.
      @(negedge clk) rst = 1'b0;

      // Run for num_tests.
      repeat (num_tests) @(posedge clk);

      // If all predictions are correct, print out the counts.
      $display("\nNumber of PC stall cycles: %0d.", stalls);
      $display("Number of branches predicted to be taken: %0d.", predicted_taken_count);
      $display("Number of branches predicted to be not taken: %0d.", predicted_not_taken_count);
      $display("Number of penalty cycles for misprediction: %0d.", misprediction_count);
      $display("Number of branches actually taken: %0d.", actual_taken_count);
      $display("Number of branch instructions executed: %0d.", branch_count);
      $display("Number of instructions executed: %0d.", num_tests);
      $display("Accuracy of predictor: %0f%%.", (1.0 - (real'(misprediction_count) / real'(branch_count))) * 100);
      
      // If we reached here it means all tests passed.
      $display("\nYAHOO!! All tests passed.");
      $stop();
  end

  always 
    #5 clk = ~clk; // toggle clock every 5 time units.

  always @(posedge clk) begin
    if (rst)
      PC_curr <= 16'h0000;
    else if (enable) begin
      if (update_PC)
        PC_curr <= actual_target;
      else if (expected_prediction[1])
        PC_curr <= expected_predicted_target;
      else
        PC_curr <= PC_curr + 16'h0002;
    end
  end

  // Model Decode stage.
  always @(posedge clk) begin
    test_counter = test_counter + 1;

    case (test_counter % 8)
      0, 1:  // 25% of the time, randomize is_branch
        is_branch = $random % 2;
      
      2, 3:  // 25% of the time, randomize actual_taken
        actual_taken = $random % 2;
      
      4, 5:  // 25% of the time, randomize actual_target
        actual_target = (actual_taken) ? (16'h0000 + ($random % num_tests) * 2) : 16'h0000;

      6:  // 12.5% of the time, randomize enable
        enable = $random % 2;
      
      default: begin  // 12.5% of the time, randomize everything
        is_branch = $random % 2;
        actual_taken = $random % 2;
        actual_target = (actual_taken) ? (16'h0000 + ($random % num_tests) * 2) : 16'h0000;
        enable = $random % 2;
      end
    endcase
  end

  // Get the counts for debugging.
  always @(negedge clk) begin
    // Count the number of stalls.
    if (!enable) begin
      stalls++;
    end else begin
      // Track actual taken count.
      if (actual_taken && is_branch)
        actual_taken_count++;

      // Track predicted counts.
      if (IF_ID_prediction[1] && is_branch) 
        predicted_taken_count++;
      else if (!IF_ID_prediction[1] && is_branch)
        predicted_not_taken_count++;
      
      // Track penalty count (how many times we update the PC).
      if (update_PC) 
        misprediction_count++;
      
      // Track how many times the instruction was a branch.
      if (is_branch) 
        branch_count++;
    end
  end

  // Model the PC curr register.
  always @(posedge clk)
    if (rst)
      IF_ID_PC_curr <= 16'h0000;
    else if (enable)
      IF_ID_PC_curr <= PC_curr;
  
  // Model the prediction register.
  always @(posedge clk)
    if (rst)
      IF_ID_prediction <= 2'b00;
    else if (enable)
      IF_ID_prediction <= expected_prediction;
  
  // Model the prediction target register.
  always @(posedge clk)
    if (rst)
      IF_ID_predicted_target <= 16'h0000;
    else if (enable)
      IF_ID_predicted_target <= expected_predicted_target;
  
  // Indicates branch is actually taken.
  assign branch_taken = (is_branch & actual_taken);

  // It is mispredicted when the predicted taken value doesn't match the actual taken value.
  assign mispredicted = (IF_ID_prediction[1] != actual_taken);

  // A target is miscomputed when the predicted target differs from the actual target.
  assign target_miscomputed = (IF_ID_predicted_target != actual_target);

  // Update BTB whenever the it is a branch and it is actually taken or when the target was miscomputed.
  assign wen_BTB = (is_branch) & ((actual_taken) | (target_miscomputed));

  // Update BHT on every branch.
  assign wen_BHT = (is_branch);

  // We update the PC to fetch the actual target when the predictor either predicted incorrectly
  // or when the target was miscomputed and the branch was actually taken.
  assign update_PC = (PC_curr !== actual_target) && (is_branch);

endmodule