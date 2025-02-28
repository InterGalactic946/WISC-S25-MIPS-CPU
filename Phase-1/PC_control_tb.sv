`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////////////////////
// PC_control_tb.v: Testbench for the PC Control unit              //
// This testbench verifies the functionality of the PC control     //
// by applying various test cases for branching and non-branching  //
// using various control signals and checking the returned PC addr //
/////////////////////////////////////////////////////////////////////
module PC_control_tb();

task determineCondition;
    input [2:0] C;
    input Z;
    input V;
    input N;
    output take;
    assign take =   (C == 3'b000) ? ~Z                    : // Not Equal (Z = 0)
                    (C == 3'b001) ? Z                     : // Equal (Z = 1)
                    (C == 3'b010) ? (~Z & ~N)          : // Greater Than (Z = N = 0)
                    (C == 3'b011) ? N                    : // Less Than (N = 1)
                    (C == 3'b100) ? (Z | (~Z & ~N)) : // Greater Than or Equal (Z = 1 or Z = N = 0)
                    (C == 3'b101) ? (Z | N)            : // Less Than or Equal (Z = 1 or N = 1)
                    (C == 3'b110) ? V                     : // Overflow (V = 1)
                    (C == 3'b111) ? 1'b1                     : // Unconditional (always executes)
                    1'b0;                                      // Default: Condition not met (shouldn't happen if ccc is valid)

endtask

reg [2:0] C;            // 3-bit condition code
reg [8:0] I;            // 9-bit signed offset right shifted by one
wire [2:0] F;           // 3-bit flag register inputs for (F[2] = Z, F[1] = V, F[0] = N)
reg [15:0] Rs;          // Register source input for the BR instruction
reg Branch;             // Indicates a branch instruction.
reg BR;                 // Indicates a BR instruction vs a B instruction
reg [15:0] PC_in;       // 16-bit address of the current instruction
wire [15:0] PC_out;     // 16-bit address of the new instruction
reg [15:0] expected_PC; // expected PC address given the conditions
integer operations;  // number of successful operations preformed
reg error;              // error flag if any test fails to pass
reg Z, V, N;            // (Z)ero, O(V)erflow, and Sig(N) flags to set F
reg branched;           // Indicates if a branch should be taken

/////////////////////
// Instantiate DUT //
/////////////////////
assign F = {Z,V,N};
PC_control PCC(.C(C), .I(I), .F(F), .Rs(Rs), .Branch(Branch), .BR(BR), .PC_in(PC_in), .PC_out(PC_out));

// Initialize the inputs and expected outputs and wait till all tests finish.
initial begin
    C = 3'b000;     // Not-equal condition
    I = 9'b0000000;       // No offset
    Z = 1'b0;       // No flags set 
    V = 1'b0;
    N = 1'b0;
    Rs = 16'h0000;     // No base value for offset
    Branch = 1'b0;  // Immediate branching
    BR = 1'b0;      // Conditional branching
    PC_in = 16'h0000;  // Start PC addr at mem 0
    expected_PC = 16'h0000;// Initialize expected PC addr
    error = 1'b0;   // Initialize no error
    operations = 0; // Initialize operation counter
    branched = 1'b0;   // Initialize a non-branched operation

    #5; // wait to initial inputs

    // Validate initial base case -- should increment PC by 2
    expected_PC = PC_in + 2;
    if (PC_out != expected_PC) begin
        $display("Base Case failed -> Expected PC addr: 0x%h\tGot: ", expected_PC, PC_out);
        error = 1'b1;
        $stop();
    end
    
    #1;

    // Assume non-branching works if base case passes
    // All following tests use branching
    Branch = 1'b1;

    // 8000 random tests for conditional immediate branching
    // 1000 test are preformed for each condition
    repeat (8) begin
        repeat (1000) begin
            // Choose random Z, V, and N flags
            Z = $random%2;
            V = $random%2;
            N = $random%2;

            // Choose random immediate value
            I = $random%(1'b1 << 10);

            // Choose a random base PC addr
            PC_in = $random%(1'b1 << 16);
            
            // Reset expected PC addr
            expected_PC = 0;
            
            // Determine if branch is taken
            determineCondition(.C(C), .Z(Z), .V(V), .N(N), .take(branched));
            
            expected_PC = PC_in + 2;
            expected_PC = (branched) ? expected_PC + (I << 1) : expected_PC;
            
            #1; // wait for values to be set

            if (branched) begin
                if (PC_out !== expected_PC) begin
                    $display("FAIL! Expected PC addr: 0x%h\tGot: 0x%h", expected_PC, PC_out);
                    error = 1'b1;
                end
            end else begin
                if (PC_out !== expected_PC) begin
                    $display("FAIL! Expected PC addr: 0x%h\tGot: 0x%h", expected_PC, PC_out);
                    error = 1'b1;
                end
            end

            if (!error) operations = operations + 1;
        end
        // Change the branch condition
        // Will overflow in last loop back to 0
        C = C + 1;
    end

    if (error) begin
        $display("FAIL! At least one test failed with immediate branching.");
        $display("%d operations of 8000 passed before failing", operations);
        $display("Consider checking condition code 0b%3b.", $floor(operations/1000));
        $stop();
    end

    // Switch to register branching
    BR = 1'b1;
    // Reset operation counter
    operations = 0;
    
    #1;

    // 8000 random tests for conditional register branching
    // 1000 test are preformed for each condition
    repeat (8) begin
        repeat (1000) begin
            // Choose random Z, V, and N flags
            Z = $random%2;
            V = $random%2;
            N = $random%2;

            // Choose random register value (multiple of 2)
            Rs = $random%(1'b1 << 16);

            // Choose a random base PC addr
            PC_in = $random%(1'b1 << 16);
            
            // Reset expected PC addr
            expected_PC = 0;
            
            // Determine if branch is taken
            determineCondition(.C(C), .Z(Z), .V(V), .N(N), .take(branched));
            
            expected_PC = PC_in + 2;
            expected_PC = (branched) ? Rs : expected_PC;
            
            #1; // wait for values to be set

            if (branched) begin
                if (PC_out !== expected_PC) begin
                    $display("FAIL! Expected PC addr: 0x%h\tGot: 0x%h", expected_PC, PC_out);
                    error = 1'b1;
                end
            end else begin
                if (PC_out !== expected_PC) begin
                    $display("FAIL! Expected PC addr: 0x%h\tGot: 0x%h", expected_PC, PC_out);
                    error = 1'b1;
                end
            end

            if (!error) operations = operations + 1;
        end
        // Change the branch condition
        // Will overflow in last loop back to 0
        C = C + 1;
    end
    
    if (error) begin
        $display("FAIL! At least one test failed with register branching.");
        $display("%d operations of 8000 passed before failing", operations);
        $display("Consider checking condition code 0b%3b.", $floor(operations/1000));
        $stop();
    end

    $display("YIPEE :3 !! All tests passed!");
    $stop();
end

endmodule