////////////////////////////////////////////////////////////////////
// Fetch_tb.sv: Testbench for the Fetch Stage of the CPU          //
// Verifies functionality by comparing outputs with a scoreboard  //
// class.                                                         //
////////////////////////////////////////////////////////////////////

module Fetch_tb();

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
      .actual_target(actual_target), 
      .actual_taken(actual_taken), 
      .wen_BTB(wen_BTB),
      .wen_BHT(wen_BHT),
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
  Fetch_model iFETCH_model (
      .clk(clk), 
      .rst(rst), 
      .stall(PC_stall), 
      .actual_target(actual_target), 
      .actual_taken(actual_taken), 
      .wen_BTB(wen_BTB),
      .wen_BHT(wen_BHT),
      .update_PC(update_PC),
      .IF_ID_PC_curr(IF_ID_PC_curr),
      .IF_ID_prediction(IF_ID_prediction), 
      
      .PC_next(expected_PC_next), 
      .PC_inst(expected_PC_inst), 
      .PC_curr(expected_PC_curr),
      .prediction(expected_prediction),
      .predicted_target(expected_predicted_target)
  );

  // A task to verify the DUT vs model.
  task verify_DUT();
    begin      
      // Verify the PC next.
      if (PC_next !== expected_PC_next) begin
        $display("ERROR: PC_next=0x%h, expected_PC_next=0x%h.", PC_next, expected_PC_next);
        $stop();
      end

      // Verify the PC instruction.
      if (PC_inst !== expected_PC_inst) begin
        $display("ERROR: PC_inst=0x%h, expected_PC_inst=0x%h.", PC_inst, expected_PC_inst);
        $stop();
      end

      // Verify the PC.
      if (PC_curr !== expected_PC_curr) begin
        $display("ERROR: PC_curr=0x%h, expected_PC_curr=0x%h.", PC_curr, expected_PC_curr);
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

  // Dumps the contents of the Branch History Table (BHT) and Branch Target Buffer (BTB)
  task dump_BHT_BTB();
  begin
    integer i;

    static reg [1:0] prev_BHT_DUT [0:15];  // Store previous BHT state for DUT
    static reg [15:0] prev_BTB_DUT [0:15]; // Store previous BTB state for DUT

    // Print full BHT contents (without IF_ID_PC_curr)
    $display("\n====== FULL BHT CONTENTS - MODEL vs DUT ======");
    for (i = 0; i < 16; i = i + 1) begin
      $display("BHT[%0d] -> Model: %b | DUT: %b", i, iFETCH_model.iDBP_model.BHT[i], iDUT.iDBP.iBHT.iMEM_BHT.mem[i][1:0]);
    end

    // Print update statements for BHT
    $display("\n====== BHT UPDATES - DUT ======");
    for (i = 0; i < 16; i = i + 1) begin
      if (iDUT.iDBP.iBHT.iMEM_BHT.mem[i][1:0] !== prev_BHT_DUT[i]) begin
        $display("BHT[%0d] UPDATED! -> DUT: %b | IF_ID_PC_curr: 0x%h", 
                i, iDUT.iDBP.iBHT.iMEM_BHT.mem[i][1:0], iDUT.IF_ID_PC_curr);
        prev_BHT_DUT[i] = iDUT.iDBP.iBHT.iMEM_BHT.mem[i][1:0]; // Update tracking variable
      end
    end

    // Print update statements for BTB
    $display("\n====== BTB UPDATES - DUT ======");
    for (i = 0; i < 16; i = i + 1) begin
      if (iDUT.iDBP.iBTB.iMEM_BTB.mem[i] !== prev_BTB_DUT[i]) begin
        $display("BTB[%0d] UPDATED! -> DUT: 0x%h | IF_ID_PC_curr: 0x%h", 
                i, iDUT.iDBP.iBTB.iMEM_BTB.mem[i], iDUT.IF_ID_PC_curr);
        prev_BTB_DUT[i] = iDUT.iDBP.iBTB.iMEM_BTB.mem[i]; // Update tracking variable
      end
    end

    // Print full BTB contents (without IF_ID_PC_curr)
    $display("\n====== FULL BTB CONTENTS - MODEL vs DUT ======");
    for (i = 0; i < 16; i = i + 1) begin
      $display("BTB[%0d] -> Model: 0x%h | DUT: 0x%h", i, iFETCH_model.iDBP_model.BTB[i], iDUT.iDBP.iBTB.iMEM_BTB.mem[i]);
    end
    
    // Break for clarity
    $display("\n---------------------------------------------------");
  end
  endtask

  // At negative edge of clock, verify the predictions match the model.
  always @(negedge clk) begin
    // Verify the DUT other than reset.
    if (!rst)
      verify_DUT();

    // Dump the contents of memory whenever we write to the BTB or BHT.
    if (wen_BHT || wen_BTB)
      dump_BHT_BTB();
  end

  // Initialize the testbench.
  initial begin
      clk = 1'b0;              // Initially clk is low
      rst = 1'b0;              // Initially rst is low
      enable = 1'b1;           // Enable the branch predictor
      is_branch = 1'b0;        // Initially no branch
      actual_taken = 1'b0;     // Initially the branch is not taken
      actual_target = 16'h0000; // Set target to 0 initially
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
      num_tests = 20;

      // Wait for the first clock cycle to assert reset
      @(posedge clk);
      
      // Assert reset
      @(negedge clk) begin
        rst = 1'b1;
        loaded = 1'b1;
      end

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


  // Model Decode stage.
  always @(posedge clk) begin
    test_counter = test_counter + 1;

    case (test_counter % 8)
      0, 1:  // 25% of the time, randomize is_branch
        is_branch = $random % 2;
      
      2, 3:  // 25% of the time, randomize actual_taken
        actual_taken = $random % 2;
      
      4, 5:  // 25% of the time, randomize actual_target
        actual_target = (actual_taken) ? $random : 16'h0000;

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
      IF_ID_PC_curr <= expected_PC_curr[3:0];
  
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