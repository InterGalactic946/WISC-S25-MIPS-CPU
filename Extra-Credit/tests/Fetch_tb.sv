////////////////////////////////////////////////////////////////////
// Fetch_tb.sv: Testbench for the Fetch Stage of the CPU          //
// Verifies functionality by comparing outputs with a scoreboard  //
// class.                                                         //
////////////////////////////////////////////////////////////////////

import Monitor_tasks::*;
import Verification_tasks::*;

module Fetch_tb();

  logic clk;                              // Clock signal
  logic rst;                              // Reset signal
  
  logic enable;                           // Enable signal for the branch predictor
  logic wen_BTB;                          // Write enable for BTB (Branch Target Buffer) (from the decode stage)
  logic wen_BHT;                          // Write enable for BHT (Branch History Table) (from the decode stage)
  logic update_PC;                        // Signal to update the PC with the actual target

  logic is_branch;                        // Flag to indicate if the previous instruction was a branch
  
  logic actual_taken;                     // Flag indicating whether the branch was actually taken
  string fetch_msg;                       // Systematically prints out the state of the instruction fetched
  logic [15:0] actual_target;             // Actual target address
  logic [15:0] branch_target;             // Actual target address for the branch instruction
  logic [1:0] IF_ID_prediction;           // Pipelined predicted signal passed to the decode stage
  logic [15:0] IF_ID_predicted_target;    // Predicted target passed to the decode stage
  logic [15:0] IF_ID_PC_curr;             // IF/ID stage current PC value

  logic mispredicted;                     // Indicates previous instruction's fetch mispredicted.
  logic target_miscomputed;               // Indicates previous instruction's fetch miscomputed the target.
  logic branch_taken;                     // Indicates branch was actually taken.

  integer predicted_taken_actual_not_count;       // Number of times predictor said taken, but branch wasn't (false positive).
  integer predicted_not_taken_actual_taken_count; // Number of times predictor said not taken, but branch was (false negative).
  integer actual_taken_count;                     // Number of times branch was actually taken.
  integer predicted_taken_count;                  // Number of times branch was predicted to be taken.
  integer predicted_not_taken_count;              // Number of times branch was predicted to not be taken.
  integer misprediction_count;                    // Number of times branch prediction was incorrect.
  integer test_counter;                           // Number of tests executed (e.g., instructions tested).
  integer stalls;                                 // Number of PC stall cycles due to pipeline bubbles or hazards.
  integer branch_count;                           // Number of branch instructions executed.
  integer num_tests;                              // Number of test cases to execute.
    
  logic [15:0] PC_next;                   // Computed next PC value
  logic [15:0] PC_inst;                   // Instruction fetched from the current PC address
  logic [15:0] PC_curr;                   // Current PC value
  logic [1:0] prediction;                 // The 2-bit predicted taken flag from the predictor
  logic [15:0] predicted_target;          // The predicted target address from the predictor
  
  logic [15:0] expected_PC_next;          // The expected computed next PC value
  logic [15:0] expected_PC_inst;          // The expected instruction fetched from the current PC address
  logic [15:0] expected_PC_curr;          // The expected current PC value
  logic [1:0] expected_prediction;        // The expected prediction from the model DBP
  logic [15:0] expected_predicted_target; // The expected predicted target address from from the model DBP

  // Instantiate the DUT: Dynamic Branch Predictor.
  Fetch iDUT (
    .clk(clk), 
    .rst(rst), 
    .stall(enable), 
    .actual_taken(actual_taken),
    .wen_BHT(wen_BHT),
    .branch_target(branch_target),
    .wen_BTB(wen_BTB),
    .actual_target(actual_target),
    .update_PC(update_PC),
    .IF_ID_PC_curr(IF_ID_PC_curr),
    .IF_ID_prediction(IF_ID_prediction), 
      
    .PC_next(PC_next), 
    .PC_inst(PC_inst), 
    .PC_curr(PC_curr),
    .prediction(prediction),
    .predicted_target(predicted_target)
  );

  // Instantiate the model fetch unit.
  Fetch_model iFETCH (
    .clk(clk), 
    .rst(rst), 
    .stall(enable), 
    .actual_taken(actual_taken),
    .wen_BHT(wen_BHT),
    .branch_target(branch_target),
    .wen_BTB(wen_BTB),
    .actual_target(actual_target),
    .update_PC(update_PC),
    .IF_ID_PC_curr(IF_ID_PC_curr),
    .IF_ID_prediction(IF_ID_prediction), 
      
    .PC_next(expected_PC_next), 
    .PC_inst(expected_PC_inst), 
    .PC_curr(expected_PC_curr),
    .prediction(expected_prediction),
    .predicted_target(expected_predicted_target)
  );

  // At negative edge of clock, verify the predictions match the model.
  always @(posedge clk) begin
    // Verify the DUT other than reset.
    if (!rst) begin
      verify_FETCH(
              .PC_stall(enable),
              .expected_PC_stall(enable),
              .PC_next(PC_next), 
              .HLT(1'b0),
              .expected_PC_next(expected_PC_next), 
              .PC_inst(PC_inst), 
              .expected_PC_inst(expected_PC_inst), 
              .PC_curr(PC_curr), 
              .expected_PC_curr(expected_PC_curr), 
              .prediction(prediction), 
              .expected_prediction(expected_prediction), 
              .predicted_taken(iDUT.predicted_taken),
              .expected_predicted_taken(iFETCH.predicted_taken),
              .predicted_target(predicted_target), 
              .expected_predicted_target (expected_predicted_target),
              .fetch_msg(fetch_msg)
      );

      $display(fetch_msg);

      // Dump the contents of memory whenever we write to the BTB or BHT.
      if (wen_BHT || wen_BTB)
        log_BTB_BHT_dump (
            .model_BHT(iFETCH.iDBP_model.BHT),
            .model_BTB(iFETCH.iDBP_model.BTB)
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
      branch_target = 16'h0000; // Set target to 0 initially
      fetch_msg = "";

      // Initialize counter values.
      predicted_taken_actual_not_count = 0;
      predicted_not_taken_actual_taken_count = 0;
      actual_taken_count = 0;
      predicted_taken_count = 0;
      predicted_not_taken_count = 0;
      misprediction_count = 0;
      branch_count = 0;
      test_counter = 0;
      stalls = 0;

      // initialize num_tests.
      num_tests = 300; // Number of tests to run.

      // Wait for the first clock cycle to assert reset
      @(posedge clk);
      
      // Assert reset
      @(negedge clk) rst = 1'b1;

      // Deassert reset and start testing.
      @(negedge clk) rst = 1'b0;

      // Run for num_tests.
      repeat (num_tests) begin
        @(posedge clk);
      end

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
      $display("============================================================\n");
      
      // If we reached here it means all tests passed.
      $display("YAHOO!! All tests passed.");
      $stop();
  end

  always 
    #5 clk = ~clk; // toggle clock every 5 time units.


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


  // Debugging counters for branch prediction analysis.
  always @(posedge clk) begin
    if (!enable) begin
      // Count the number of stalls.
      stalls++;
    end else begin
      if (is_branch) begin
        branch_count++;

        // Track actual taken count.
        if (actual_taken)
          actual_taken_count++;

        // Track prediction stats.
        if (IF_ID_prediction[1]) begin
          predicted_taken_count++;

          // Case: predicted taken but actually not taken (false positive)
          if (!actual_taken)
            predicted_taken_actual_not_count++;
        end else begin
          predicted_not_taken_count++;

          // Case: predicted not taken but actually taken (false negative)
          if (actual_taken)
            predicted_not_taken_actual_taken_count++;
        end

        // Track mispredictions — if PC was updated due to wrong prediction
        if (update_PC)
          misprediction_count++;
      end
    end
  end

  // Model the PC curr register.
  always @(posedge clk)
    if (rst)
      IF_ID_PC_curr <= 16'h0000;
    else if (enable)
      IF_ID_PC_curr <= expected_PC_curr;
  
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
  assign mispredicted = (IF_ID_prediction[1] !== actual_taken);

  // A target is miscomputed when the predicted target differs from the actual target.
  assign target_miscomputed = (IF_ID_predicted_target !== actual_target);

  // Update BTB whenever the it is a branch and it is actually taken or when the target was miscomputed.
  assign wen_BTB = (is_branch) & ((actual_taken) | (target_miscomputed));

  // Update BHT on every branch.
  assign wen_BHT = (is_branch);

  // We update the PC to fetch the actual target when the current instruction fetched is not the same as the actual target, on a branch instruction.
  assign update_PC = (actual_target !== PC_curr) & (is_branch);

endmodule