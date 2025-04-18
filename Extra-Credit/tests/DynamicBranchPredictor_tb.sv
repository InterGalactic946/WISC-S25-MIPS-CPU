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

  // ────────────── Misprediction categories ──────────────
  integer predicted_taken_actual_not_count;         // Predictor said taken, but actually not taken (false positive).
  integer predicted_not_taken_actual_taken_count;   // Predictor said not taken, but actually taken (false negative).

  // ────────────── Confidence-based correct predictions ──────────────
  integer strong_taken_correct;                     // Predicted strongly taken and was correct.
  integer weak_taken_correct;                       // Predicted weakly taken and was correct.
  integer strong_not_taken_correct;                 // Predicted strongly not taken and was correct.
  integer weak_not_taken_correct;                   // Predicted weakly not taken and was correct.

  // ────────────── Confidence-based incorrect predictions ──────────────
  integer strong_taken_incorrect;                   // Predicted strongly taken and was incorrect.
  integer weak_taken_incorrect;                     // Predicted weakly taken and was incorrect.
  integer strong_not_taken_incorrect;               // Predicted strongly not taken and was incorrect.
  integer weak_not_taken_incorrect;                 // Predicted weakly not taken and was incorrect.

  // ────────────── General statistics ──────────────
  integer actual_taken_count;                       // Number of times branch was actually taken.
  integer predicted_taken_count;                    // Number of times branch was predicted to be taken.
  integer predicted_not_taken_count;                // Number of times branch was predicted to not be taken.
  integer misprediction_count;                      // Number of times branch prediction was incorrect.
  integer test_counter;                             // Number of tests executed (e.g., instructions tested).
  integer stalls;                                   // Number of PC stall cycles due to pipeline bubbles or hazards.
  integer branch_count;                             // Number of branch instructions executed.
  integer num_tests;                                // Number of test cases to execute.

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
        $display("ERROR: PC_curr=0x%h, predicted_taken=%b, expected_predicted_taken=%b.", PC_curr, predicted_taken, expected_predicted_taken);
        $stop();
      end

      // Verify the prediction.
      if (prediction !== expected_prediction) begin
        $display("ERROR: PC_curr=0x%h, prediction=%2b, expected_prediction=%2b.", PC_curr, prediction, expected_prediction);
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
  always @(posedge clk) begin
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
      rst = 1'b1;              // Initially rst is high
      enable = 1'b1;           // Enable the branch predictor
      is_branch = 1'b0;        // Initially no branch
      actual_taken = 1'b0;     // Initially the branch is not taken
      actual_target = 16'h0000; // Set target to 0 initially

      // Initialize counter values.
      predicted_taken_actual_not_count       = 0;
      predicted_not_taken_actual_taken_count = 0;

      // Confidence-based correct predictions
      strong_taken_correct        = 0;
      weak_taken_correct          = 0;
      strong_not_taken_correct    = 0;
      weak_not_taken_correct      = 0;

      // Confidence-based incorrect predictions
      strong_taken_incorrect      = 0;
      weak_taken_incorrect        = 0;
      strong_not_taken_incorrect  = 0;
      weak_not_taken_incorrect    = 0;

      // General statistics
      actual_taken_count          = 0;
      predicted_taken_count       = 0;
      predicted_not_taken_count   = 0;
      misprediction_count         = 0;
      branch_count                = 0;
      test_counter                = 0;
      stalls                      = 0;

      // initialize num_tests.
      num_tests = 70000;

      // Wait for the first clock cycle to assert reset
      @(posedge clk);
      
      // Assert reset
      @(negedge clk) rst = 1'b1;

      // Deassert reset and start testing.
      @(negedge clk) rst = 1'b0;

      // Run for num_tests.
      repeat (num_tests) @(posedge clk);

      // If all predictions are correct, print out the counts.
      $display("\n================ Branch Predictor Statistics ================");

      // General execution stats
      $display("Total instructions executed:                 %0d", num_tests);
      $display("Total branch instructions executed:          %0d", branch_count);
      $display("  └─ Actually taken:                         %0d", actual_taken_count);
      $display("  └─ Actually not taken:                     %0d", branch_count - actual_taken_count);
      
      // Prediction outcomes
      $display("Predicted taken:                             %0d", predicted_taken_count);
      $display("Predicted not taken:                         %0d", predicted_not_taken_count);
      $display("  ├─ False positives (pred taken, not taken):%0d", predicted_taken_actual_not_count);
      $display("  └─ False negatives (pred not taken, taken):%0d", predicted_not_taken_actual_taken_count);

      // Misprediction and stall stats
      $display("Total mispredictions:                        %0d", misprediction_count);
      $display("Total PC stall cycles:                       %0d", stalls);

      // Accuracy and rates
      if (branch_count > 0) begin
        $display("Prediction accuracy:                         %0.2f%%", 
                100.0 * (1.0 - real'(misprediction_count) / real'(branch_count)));
        $display("False positive rate:                         %0.2f%%", 
                100.0 * real'(predicted_taken_actual_not_count) / real'(branch_count));
        $display("False negative rate:                         %0.2f%%", 
                100.0 * real'(predicted_not_taken_actual_taken_count) / real'(branch_count));
      end else begin
        $display("Prediction accuracy:                         N/A (no branches)");
      end

      // Confidence breakdown
      $display("\n---------------- Confidence Breakdown ----------------");
      $display("Correct Predictions:");
      $display("  ├─ Strong taken correct:                   %0d", strong_taken_correct);
      $display("  ├─ Weak taken correct:                     %0d", weak_taken_correct);
      $display("  ├─ Strong not-taken correct:               %0d", strong_not_taken_correct);
      $display("  └─ Weak not-taken correct:                 %0d", weak_not_taken_correct);
      $display("Incorrect Predictions:");
      $display("  ├─ Strong taken incorrect:                 %0d", strong_taken_incorrect);
      $display("  ├─ Weak taken incorrect:                   %0d", weak_taken_incorrect);
      $display("  ├─ Strong not-taken incorrect:             %0d", strong_not_taken_incorrect);
      $display("  └─ Weak not-taken incorrect:               %0d", weak_not_taken_incorrect);
      
      $display("============================================================\n");

      // If we reached here it means all tests passed.
      $display("YAHOO!! All tests passed.");
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

  // Model Decode stage behavior using pseudo-randomized control signals.
  // Varies is_branch, actual_taken, actual_target, and enable based on test_counter mod 8.
  always @(posedge clk) begin
    test_counter <= test_counter + 1;

    case (test_counter % 8)
      0, 1: begin
        // 25% of the time: Randomize whether it's a branch.
        is_branch <= $random % 2;
      end
      
      2, 3: begin
        // 25% of the time: Randomize actual taken status.
        actual_taken <= $random % 2;
      end

      4, 5: begin
        // 25% of the time: Randomize actual target (only if taken).
        actual_target <= (actual_taken) ? (16'h0000 + ($random % (num_tests != 0 ? num_tests : 1)) * 2) : 16'h0000;
      end

      6: begin
        // 12.5% of the time: Randomize enable.
        enable <= $random % 2;
      end

      default: begin
        // 12.5% of the time: Randomize all relevant control signals.
        is_branch <= $random % 2;
        actual_taken <= $random % 2;
        actual_target <= (actual_taken) ? (16'h0000 + ($random % (num_tests != 0 ? num_tests : 1)) * 2) : 16'h0000;
        enable <= $random % 2;
      end
    endcase
  end

  // Count and categorize prediction outcomes for debugging and performance analysis.
  always @(posedge clk) begin
    if (!enable) begin
      stalls++;
    end else begin
      // Track actual taken.
      if (actual_taken && is_branch)
        actual_taken_count++;

      // Track total branch count.
      if (is_branch)
        branch_count++;

      if (is_branch) begin
        // Taken prediction
        if (IF_ID_prediction[1]) begin
          predicted_taken_count++;

          if (actual_taken) begin
            // Correct predictions
            if (IF_ID_prediction == 2'b11) strong_taken_correct++;
            else if (IF_ID_prediction == 2'b10) weak_taken_correct++;
          end else begin
            // Incorrect predictions
            if (IF_ID_prediction == 2'b11) strong_taken_incorrect++;
            else if (IF_ID_prediction == 2'b10) weak_taken_incorrect++;
            predicted_taken_actual_not_count++;
            misprediction_count++;
          end

        end 
        // Not taken prediction
        else begin
          predicted_not_taken_count++;

          if (!actual_taken) begin
            // Correct predictions
            if (IF_ID_prediction == 2'b00) strong_not_taken_correct++;
            else if (IF_ID_prediction == 2'b01) weak_not_taken_correct++;
          end else begin
            // Incorrect predictions
            if (IF_ID_prediction == 2'b00) strong_not_taken_incorrect++;
            else if (IF_ID_prediction == 2'b01) weak_not_taken_incorrect++;
            predicted_not_taken_actual_taken_count++;
            misprediction_count++;
          end
        end
      end
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
  assign wen_BTB = (is_branch) & ((actual_taken) & (target_miscomputed));

  // Update BHT on every branch.
  assign wen_BHT = (is_branch);

  // We update the PC to fetch the actual target when the predictor either predicted incorrectly
  // or when the target was miscomputed and the branch was actually taken.
  assign update_PC = (PC_curr !== actual_target) && (is_branch);

endmodule