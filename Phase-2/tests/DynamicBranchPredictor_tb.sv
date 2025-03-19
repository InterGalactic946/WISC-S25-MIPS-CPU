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
  logic [3:0] PC_curr;                      // Current PC value
  logic [3:0] IF_ID_PC_curr;                // IF/ID stage current PC value
  logic cycle_count;

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
      clk = 1'b0;              // Initially clk is low
      rst = 1'b0;              // Initially rst is low
      enable = 1'b1;           // Enable the branch predictor
      was_branch = 1'b0;       // Initially no branch
      actual_taken = 1'b0;     // Initially the branch is not taken
      actual_target = 16'h0000; // Set target to 0 initially
      branch_mispredicted = 1'b0; // Initially branch is not mispredicted
      PC_curr = 4'h0;          // Start with PC = 0
      IF_ID_PC_curr = 4'h0;    // Start with PC = 0
      IF_ID_prediction = 2'b00; // Start with strongly not taken prediction (prediction[1] = 0)

      // Initialize counter values.
      actual_taken_count = 0;
      predicted_taken_count = 0;
      predicted_not_taken_count = 0;
      misprediction_count = 0;

      // Maximum number of cycles to avoid infinite loop
      // max_cycles = 10; // Set a threshold for the number of cycles

      // Wait for the first clock cycle to assert reset
      @(posedge clk);
      
      // Assert reset
      @(negedge clk) rst = 1'b1;

      // Deassert reset and start testing.
      @(negedge clk) begin
        rst = 1'b0;
        PC_curr = 4'h2;   // Fetch instruction at PC=0x2 (Branch instruction)

        // Check initial prediction (Strongly not taken)
        verify_prediction_and_target();
      end

      // At fetch stage.
      @(posedge clk);
      // Initial fetch, verify the prediction and target
      verify_prediction_and_target();

      // At decode stage.
      @(posedge clk);
      // Update signals for branch taken and set target
      @(negedge clk) begin
        was_branch = 1'b1;        // Indicates branch
        actual_taken = 1'b1;      // Actually taken
        actual_target = 16'h0020; // Target if taken
        PC_curr = actual_target[3:0]; // Update PC to the target address
      end

      // Fetch the target again, simulate branch misprediction.
      @(posedge clk);
      // Second fetch at target, expect a misprediction again
      verify_prediction_and_target();

      // At decode stage again.
      @(posedge clk);
      // Update conditions for second branch
      @(negedge clk) begin
        was_branch = 1'b1;        // Indicates branch
        actual_taken = 1'b1;      // Actually taken
        actual_target = 16'h0020; // Branch target loops back to the same place
        PC_curr = actual_target[3:0];
      end

      // Set up a counter to prevent infinite loops
      cycle_count = 0;
      while (prediction[1] !== 1'b1 && cycle_count < 10) begin
        // Print the prediction and target for debugging
        $display("Cycle %0d: PC_curr=0x%h, prediction[1]=0b%b, predicted_target=0x%h", cycle_count, PC_curr, prediction[1], predicted_target);

        // Verify the prediction and target
        verify_prediction_and_target();

        // At decode stage again, update signals
        @(posedge clk);
        @(negedge clk) begin
          was_branch = 1'b1;
          actual_taken = 1'b1;
          actual_target = 16'h0020; // Target if taken, loop back to the branch instruction
          PC_curr = actual_target[3:0];
        end

        // Wait for the next fetch cycle
        @(posedge clk);
        
        // Increment cycle count
        cycle_count = cycle_count + 1;
      end

      if (cycle_count >= 10) begin
        $display("ERROR: Exceeded max cycles without correctly predicting branch.");
        $stop();
      end

      // If all predictions are correct, print out the counts.
      $display("Number of branches predicted to be taken: %0d.", predicted_taken_count);
      $display("Number of branches predicted to be not taken: %0d.", predicted_not_taken_count);
      $display("Number of mispredictions: %0d.", misprediction_count);
      $display("Number of branches actually taken: %0d.", actual_taken_count);
      $display("YAHOO!! All tests passed. Branch predictor predicted correctly after %0d cycles.", misprediction_count);
      $stop();
  end

  // A task to verify the prediction and target.
  task verify_prediction_and_target;
    begin
      // Verify the prediction (expecting weakly not taken or weakly taken after a few cycles)
      if (prediction[1] !== expected_prediction[1]) begin
        $display("ERROR: PC_curr=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b.", PC_curr, prediction[1], expected_prediction[1]);
        $stop();
      end
      
      // Verify the predicted target
      if (predicted_target !== expected_predicted_target) begin
        $display("ERROR: PC_curr=0x%h, predicted_target=0x%h, expected_predicted_target=0x%h.", PC_curr, predicted_target, expected_predicted_target);
        $stop();
      end
    end
  endtask

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
  
  // We get the branch mispredicted condition.
  assign branch_mispredicted = (IF_ID_prediction[1] !== actual_taken) && (was_branch);

endmodule