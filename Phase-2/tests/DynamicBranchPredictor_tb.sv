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
  logic wen_BTB;                          // Write enable for BTB (Branch Target Buffer) (from the decode stage)
  logic wen_BHT;                          // Write enable for BHT (Branch History Table) (from the decode stage)
  logic update_PC;                        // Signal to update the PC with the actual target

  logic is_branch;                        // Flag to indicate if the previous instruction was a branch
  
  logic actual_taken;                     // Flag indicating whether the branch was actually taken
  logic [15:0] actual_target;             // Actual target address of the branch
  logic [1:0] IF_ID_prediction;           // Pipelined predicted signal passed to the decode stage
  logic [15:0] IF_ID_predicted_target;    // Predicted target passed to the decode stage
  logic [15:0] PC_curr;                   // Current PC value
  logic [3:0] IF_ID_PC_curr;              // IF/ID stage current PC value

  logic mispredicted;                     // Indicates previous instruction's fetch mispredicted.
  logic target_miscomputed;               // Indicates previous instruction's fetch miscomputed the target.
  logic branch_taken;                     // Indicates branch was actually taken.

  integer actual_taken_count;             // Number of times branch was actually taken.
  integer predicted_taken_count;          // Number of times branch was predicted to be taken.
  integer predicted_not_taken_count;      // Number of times branch was predicted to not be taken.
  integer misprediction_count;            // Number of times branch was mispredicted.
  integer stalls;                         // Number of PC stalls.
  integer num_tests;                      // Number of test cases to execute.

  wire [1:0] prediction;                  // The 2-bit predicted taken flag from the predictor
  wire [15:0] predicted_target;           // The predicted target address from the predictor
  wire [1:0] expected_prediction;         // The expected prediction from the model DBP
  wire [15:0] expected_predicted_target;  // The expected predicted target address from from the model DBP

  // Instantiate the DUT: Dynamic Branch Predictor.
  DynamicBranchPredictor iDUT (
    .clk(clk), 
    .rst(rst), 
    .PC_curr(PC_curr[3:0]), 
    .IF_ID_PC_curr(IF_ID_PC_curr), 
    .IF_ID_prediction(IF_ID_prediction), 
    .enable(enable),
    .wen_BTB(wen_BTB),
    .wen_BHT(wen_BHT),
    .actual_taken(actual_taken),
    .actual_target(actual_target),  
    
    .prediction(prediction), 
    .predicted_target(predicted_target)
  );

  // Instantiate the model dynamic branch predictor.
  DynamicBranchPredictor_model iDBP_model (
    .clk(clk), 
    .rst(rst), 
    .PC_curr(PC_curr[3:0]), 
    .IF_ID_PC_curr(IF_ID_PC_curr), 
    .IF_ID_prediction(IF_ID_prediction), 
    .enable(enable),
    .wen_BTB(wen_BTB),
    .wen_BHT(wen_BHT),
    .actual_taken(actual_taken),
    .actual_target(actual_target),  
    
    .prediction(expected_prediction), 
    .predicted_target(expected_predicted_target)
  );

  // A task to verify the prediction and target.
  task verify_prediction_and_target();
    begin
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
    // Verify the predictions.
    verify_prediction_and_target();

    // // Dump the contents of memory whenever we write to the BTB or BHT.
    // if (wen_BHT || wen_BTB)
    //   dump_BHT_BTB();
  end

  // Dumps the contents of the Branch History Table (BHT) and Branch Target Buffer (BTB)
  // for both the DUT and Model, along with the PC_curr values.
  task dump_BHT_BTB(); 
  begin
    // Loop variable.
    integer i;

    // Read out the memory contents.
    $display("\n====== Branch History Table (BHT) - MODEL vs DUT ======");
      for (i = 0; i < 16; i = i + 1) begin
        $display("BHT[%0d] -> Model: %b | DUT: %b | IF_ID_PC_curr -> Model: 0x%h | DUT: 0x%h", 
                i, 
                iDBP_model.BHT[i], iDUT.iBHT.iMEM_BHT.mem[i][1:0], 
                iDBP_model.IF_ID_PC_curr, iDUT.IF_ID_PC_curr);
      end

      $display("\n====== Branch Target Buffer (BTB) - MODEL vs DUT ======");
      for (i = 0; i < 16; i = i + 1) begin
        $display("BTB[%0d] -> Model: 0x%h | DUT: 0x%h | IF_ID_PC_curr -> Model: 0x%h | DUT: 0x%h", 
                i, 
                iDBP_model.BTB[i], iDUT.iBTB.iMEM_BTB.mem[i], 
                iDBP_model.IF_ID_PC_curr, iDUT.IF_ID_PC_curr);
      end
    end
  endtask

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
      stalls = 0;

      // initialize num_tests.
      num_tests = 10000000;

      // Wait for the first clock cycle to assert reset
      @(posedge clk);
      
      // Assert reset
      @(negedge clk) rst = 1'b1;

      // Deassert reset and start testing.
      @(negedge clk) rst = 1'b0;

      // Run for num_tests.
      repeat (num_tests) @(posedge clk);

      // Dump memory conteents.
      dump_BHT_BTB();

      // If all predictions are correct, print out the counts.
      $display("\nNumber of PC stall cycles: %0d.", stalls);
      $display("Number of branches predicted to be taken: %0d.", predicted_taken_count);
      $display("Number of branches predicted to be not taken: %0d.", predicted_not_taken_count);
      $display("Number of penalty cycles for misprediction: %0d.", misprediction_count);
      $display("Number of branches actually taken: %0d.", actual_taken_count);
      $display("Number of instructions executed: %0d.", num_tests);
      $display("Accuracy of predictor: %0f%%.", (1.0 - (real'(misprediction_count) / real'(num_tests))) * 100);
      
      // If we reached here it means all tests passed.
      $display("\nYAHOO!! All tests passed.");
      $stop();
  end

  always 
    #5 clk = ~clk; // toggle clock every 5 time units.

  // Model the PC register.
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

  // Model the fetch decode cycle.
  always @(posedge clk) begin
    // Get a random 1-bit value for the branch flag.
    is_branch = $random % 2;

    // Indicate if it is taken or not.
    actual_taken = $random % 2;

    // Randomly enable or disable the PC.
    // enable = $random % 2;

    // Update the actual target as a random 16-bit value if it is taken, otherwise, ignored.
    actual_target = (actual_taken) ? $random : 16'h0000;
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
      else if (is_branch)
        predicted_not_taken_count++;
      
      // Track penalty count (how many times we update the PC).
      if (update_PC) 
        misprediction_count++;
    end
  end

  // Model the PC curr register.
  always @(posedge clk)
    if (rst)
      IF_ID_PC_curr <= 4'h0;
    else if (enable)
      IF_ID_PC_curr <= PC_curr[3:0];
  
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
      IF_ID_predicted_target <= actual_target;
  
  // Indicates branch is actually taken.
  assign branch_taken = (is_branch & actual_taken);

  // It is mispredicted when the predicted taken value doesn't match the actual taken value.
  assign mispredicted = (IF_ID_prediction[1] != actual_taken);

  // A target is miscomputed when the predicted target differs from the actual target.
  assign target_miscomputed = (IF_ID_predicted_target != actual_target);

  // Update BTB whenever the it is a branch and it is actually taken or when the target was miscomputed.
  assign wen_BTB = (is_branch) & ((actual_taken) | (target_miscomputed));

  // Update BHT on a mispredicted branch instruction.
  assign wen_BHT = (is_branch & mispredicted);

  // We update the PC to fetch the actual target when the predictor either predicted incorrectly
  // or when the target was miscomputed and the branch was actually taken.
  assign update_PC = (mispredicted | target_miscomputed) & (branch_taken);

endmodule