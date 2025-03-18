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

  wire predicted_taken;                  // The predicted taken flag from the predictor
  wire [15:0] predicted_target;          // The predicted target address from the predictor
  wire expected_predicted_taken;         // The expected predicted taken flag from the model DBP
  wire [15:0] expected_predicted_target; // The expected predicted target address from from the model DBP

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

  // Task to apply random stimulus for each input of the DUT.
  task automatic apply_random_stimulus(input integer num_tests);
    integer i;
    for (i = 0; i < num_tests; i = i + 1) begin
      @(negedge clk);
      
      // Generate random values for all inputs
      PC_curr        = $random % 4;    // Random 4-bit PC address
      enable         = $random % 2;    // Random enable (0 or 1)
      was_branch     = $random % 2;    // Random branch indication (0 or 1)
      actual_taken   = $random % 2;    // Random actual branch outcome (0 or 1)
      actual_target  = $random;        // Random 16-bit target address

      // Wait for a clock cycle to allow processing
      @(posedge clk);
      
      // Verify the result on a negative edge.
      @(negedge clk) begin
        // Verify the prediction.
        if (predicted_taken !== expected_predicted_taken) begin
          $display("ERROR: PC_curr=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b",PC_curr, predicted_taken, expected_predicted_taken);
          $stop();
        end

        // Verify the predicted target.
        if (predicted_target !== expected_predicted_target) begin
          $display("ERROR: PC_curr=0x%h, predicted_target=0x%h, expected_predicted_target=0x%h", PC_curr, predicted_target, expected_predicted_target);
          $stop();
        end
      end
    end
  endtask

  // Initialize the testbench.
  initial begin
    clk = 1'b0; // initially clk is low
    rst = 1'b0; // initally rst is low
    enable = 1'b0;  // Disable the branch predictor
    was_branch = 1'b0;    // Initially no branch
    actual_taken = 1'b0;  // Initially the branch is not taken
    actual_target = 16'h0000; // Set target to 0 initially
    PC_curr = 4'h0;   // Start with PC = 0
    IF_ID_PC_curr = 4'h0; // Start with PC = 0

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
        $display("ERROR: PC_curr=0x%h, predicted_taken=0b%b, expected_predicted_taken=0b%b",PC_curr, predicted_taken, expected_predicted_taken);
        $stop();
      end

      // Verify the predicted target after reset.
      if (predicted_target !== expected_predicted_target) begin
        $display("ERROR: PC_curr=0x%h, predicted_target=0x%h, expected_predicted_target=0x%h", PC_curr, predicted_target, expected_predicted_target);
        $stop();
      end
    end

    // Apply randomized test cases.
    apply_random_stimulus(1000000);

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
