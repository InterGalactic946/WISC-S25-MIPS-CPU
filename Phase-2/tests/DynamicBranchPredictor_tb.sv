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
  integer test_counter;                   // Number of tests executed.
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

    // Dump the contents of memory whenever we write to the BTB or BHT.
    if (wen_BHT || wen_BTB)
      dump_BHT_BTB();
  end

  // Dumps the contents of the Branch History Table (BHT) and Branch Target Buffer (BTB) with formatted output
  task dump_BHT_BTB();
    integer i, file;
    
    static reg [1:0] prev_BHT_DUT [0:15];  // Store previous BHT state for DUT
    static reg [15:0] prev_BTB_DUT [0:15]; // Store previous BTB state for DUT

    // Open file for writing
    file = $fopen("./tests/output/logs/transcript/bht_btb_dump.log", "a");
    
    // Print header with clock cycle info
    $display("\n===================================================");
    $display("Branch Predictor Dump - Clock Cycle: %0d", $time);
    $display("===================================================\n");

    $fdisplay(file, "\n===================================================");
    $fdisplay(file, "Branch Predictor Dump - Clock Cycle: %0d", $time);
    $fdisplay(file, "===================================================\n");

    // Print full BHT contents
    $display("\n====== FULL BHT CONTENTS - MODEL vs DUT ======");
    $display("Index | Model | DUT");
    $display("--------------------");
    $fdisplay(file, "\n====== FULL BHT CONTENTS - MODEL vs DUT ======");
    $fdisplay(file, "Index | Model | DUT");
    $fdisplay(file, "--------------------");

    for (i = 0; i < 16; i = i + 1) begin
      $display("%2d    |  %b   |  %b", i, iDBP_model.BHT[i], iDUT.iBHT.iMEM_BHT.mem[i][1:0]);
      $fdisplay(file, "%2d    |  %b   |  %b", i, iDBP_model.BHT[i], iDUT.iBHT.iMEM_BHT.mem[i][1:0]);
    end

    // Print BHT updates
    $display("\n====== BHT UPDATES - DUT ======");
    $fdisplay(file, "\n====== BHT UPDATES - DUT ======");
    for (i = 0; i < 16; i = i + 1) begin
      if (iDUT.iBHT.iMEM_BHT.mem[i][1:0] !== prev_BHT_DUT[i]) begin
        $display("BHT[%0d] UPDATED! -> DUT: %b | IF_ID_PC_curr: 0x%h", 
                  i, iDUT.iBHT.iMEM_BHT.mem[i][1:0], iDUT.IF_ID_PC_curr);
        $fdisplay(file, "BHT[%0d] UPDATED! -> DUT: %b | IF_ID_PC_curr: 0x%h", 
                  i, iDUT.iBHT.iMEM_BHT.mem[i][1:0], iDUT.IF_ID_PC_curr);
        prev_BHT_DUT[i] = iDUT.iBHT.iMEM_BHT.mem[i][1:0]; // Update tracking variable
      end
    end

    // Print BTB updates
    $display("\n====== BTB UPDATES - DUT ======");
    $fdisplay(file, "\n====== BTB UPDATES - DUT ======");
    for (i = 0; i < 16; i = i + 1) begin
      if (iDUT.iBTB.iMEM_BTB.mem[i] !== prev_BTB_DUT[i]) begin
        $display("BTB[%0d] UPDATED! -> DUT: 0x%h | IF_ID_PC_curr: 0x%h", 
                  i, iDUT.iBTB.iMEM_BTB.mem[i], iDUT.IF_ID_PC_curr);
        $fdisplay(file, "BTB[%0d] UPDATED! -> DUT: 0x%h | IF_ID_PC_curr: 0x%h", 
                  i, iDUT.iBTB.iMEM_BTB.mem[i], iDUT.IF_ID_PC_curr);
        prev_BTB_DUT[i] = iDUT.iBTB.iMEM_BTB.mem[i]; // Update tracking variable
      end
    end

    // Print full BTB contents
    $display("\n====== FULL BTB CONTENTS - MODEL vs DUT ======");
    $display("Index | Model  | DUT");
    $display("----------------------");
    $fdisplay(file, "\n====== FULL BTB CONTENTS - MODEL vs DUT ======");
    $fdisplay(file, "Index | Model  | DUT");
    $fdisplay(file, "----------------------");

    for (i = 0; i < 16; i = i + 1) begin
      $display("%2d    |  0x%h  |  0x%h", i, iDBP_model.BTB[i], iDUT.iBTB.iMEM_BTB.mem[i]);
      $fdisplay(file, "%2d    |  0x%h  |  0x%h", i, iDBP_model.BTB[i], iDUT.iBTB.iMEM_BTB.mem[i]);
    end

    // Closing section
    $display("\n===================================================");
    $fdisplay(file, "\n===================================================");

    // Close file
    $fclose(file);
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
      $display("Number of instructions executed: %0d.", num_tests);
      $display("Accuracy of predictor: %0f%%.", (1.0 - (real'(misprediction_count) / real'(num_tests))) * 100);
      
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
        actual_target = (actual_taken) ? $random * 2 : 16'h0000;

      6:  // 12.5% of the time, randomize enable
        enable = $random % 2;
      
      default: begin  // 12.5% of the time, randomize everything
        is_branch = $random % 2;
        actual_taken = $random % 2;
        actual_target = (actual_taken) ? $random : 16'h0000;
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