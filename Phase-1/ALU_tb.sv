`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////////////////
// ALU_tb.v: Testbench for the 16-bit ALU                      //
// This testbench verifies the functionality of the 16-bit    //
// ALU by applying random stimulus to the inputs and         //
// monitoring the outputs.                                  //               
/////////////////////////////////////////////////////////////
module ALU_tb();

  reg [31:0] stim;    		           // stimulus input vector of type reg
  reg [3:0] stim_op;    		         // stimulus opcode vector of type reg
  wire [15:0] result; 		           // 16-bit result of the ALU
  wire ZF, VF, NF;     		           // zero, overflow, and signed flag set signasls of the ALU
  reg expected_ZF; 	                 // expected z_set flag
  reg expected_VF;                   // expected v_set flag
  reg expected_NF;                   // expected n_set flag
  string instr_name;                 // name of the instruction
  reg [15:0] expected_result;        // expected result
  reg [19:0] addition_operations;    // number of addition operations performed
  reg [19:0] subtraction_operations; // number of subtraction operations performed
  reg [19:0] lw_operations;          // number of load word computations performed
  reg [19:0] sw_operations;          // number of store word computations performed
  reg [19:0] xor_operations;         // number of xor operations performed
  reg [19:0] reduction_operations;   // number of reduction additions performed
  reg [19:0] asr_operations;         // number of asr operations performed
  reg [19:0] ror_operations;         // number of ror operations performed
  reg [19:0] sll_operations;         // number of sll operations performed
  reg [19:0] paddsb_operations;      // number of parallel sub-additions performed
  reg [19:0] nop_operations;         // number of nops performed
  reg error;                         // set an error flag on error
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  ALU iDUT(.ALU_In1(stim[31:16]),.ALU_In2(stim[15:0]),.Opcode(stim_op),.ALU_Out(result),.Z_set(ZF),.N_set(NF), .V_set(VF));

  // Decodes opcodes based on the instruction.
  task automatic decode_opcode();
      begin
          case (stim_op)
              4'h0: instr_name = "ADD";     // Addition
              4'h1: instr_name = "SUB";     // Subtraction
              4'h2: instr_name = "XOR";     // Bitwise XOR
              4'h3: instr_name = "RED";     // Reduction Addition
              4'h4: instr_name = "SLL";     // Shift Left Logical
              4'h5: instr_name = "SRA";     // Shift Right Arithmetic
              4'h6: instr_name = "ROR";     // Rotate Right
              4'h7: instr_name = "PADDSB";  // Parallel Sub-word Addition
              4'h8: instr_name = "LW";      // Load Word
              4'h9: instr_name = "SW";      // Store Word
              default: instr_name = "INVALID"; // Invalid opcode
          endcase
      end
  endtask

  // Task: Verify the flag set signals.
  task automatic verify_flags(input [15:0] A, input [15:0] B, input [15:0] ALU_out);
    begin
      // Get the actual flag results.
      reg ov;
      reg zero;
      reg neg;

      // It is zero when the output is zero.
      zero = ALU_out === 16'h0000;

      // It is negative when the MSB of the output is zero.
      neg = ALU_out[15];

      // Get the expected overflow based on addition/subtraction.
      if (stim_op === 4'h1) begin
        if ((A[15] === 1'b0) && (B[15] === 1'b1) && (ALU_out[15] === 1'b1)) 
          ov = 1'b1; // Overflow detected (positive - negative giving negative)
        else if ((A[15] === 1'b1) && (B[15] === 1'b0) && (ALU_out[15] === 1'b0)) 
          ov = 1'b1; // Overflow detected (negative - positive giving positive)
        else 
          ov = 1'b0; // No overflow in other cases
      end else begin
        if (A[15] === B[15]) begin
          if (ALU_out[15] !== A[15]) 
            ov = 1'b1; // Overflow detected
          else 
            ov = 1'b0; // No overflow
        end else begin
            ov = 1'b0; // No overflow when operands have different signs
        end
      end 

      // Set the flags based on the stim_op.
      if (stim_op === 4'h0 || stim_op === 4'h1 || stim_op === 4'h2 || stim_op === 4'h4 || stim_op === 4'h5 || stim_op === 4'h6) begin
        expected_ZF = zero;
      end else if (stim_op === 4'h0 || stim_op === 4'h1) begin
        expected_NF = neg;
        expected_VF = ov;
      end else begin
        expected_ZF = 1'b0;
        expected_VF = 1'b0;
        expected_NF = 1'b0;
      end

      // Verify that the zero set flag is working correctly.
      if (ZF !== expected_ZF) begin
          $display("ERROR: A: 0x%h, B: 0x%h, Mode: %s. Zero set signal expected 0x%h, got 0x%h.", A, B, instr_name, expected_ZF, ZF);
          error = 1'b1;
      end
      
      // Verify that the signed set flag is working correctly.
      if (NF !== expected_NF) begin
          $display("ERROR: A: 0x%h, B: 0x%h, Mode: %s. Signed set signal expected 0x%h, got 0x%h.", A, B, instr_name, expected_NF, NF);
          error = 1'b1;
      end

      // Verify that the overflow set flag is working correctly.
      if (VF !== expected_VF) begin
          $display("ERROR: A: 0x%h, B: 0x%h, Mode: %s. Overflow set signal expected 0x%h, got 0x%h.", A, B, instr_name, expected_VF, VF);
          error = 1'b1;
      end
    end
  endtask

  // Task: Verify the normal sum for ADD/SUB/LW/SW instructions.
  task automatic verify_sum(input [15:0] A, input [15:0] B);
    begin
      // Expected result and for ADD/SUB/LW/SW.
      if (stim_op === 4'h0)
        expected_result = A + B;
      else if (stim_op === 4'h1)
        expected_result = A - B;
      else if (stim_op === 4'h8 || stim_op === 4'h9)
        expected_result = (A & 16'hFFFE) + (B << 1'b1);
      
      // Validate that the result is the expected result.
      if ($signed(result) !== $signed(expected_result)) begin
          $display("ERROR: A: 0x%h, B: 0x%h, Mode: %s. Sum expected 0x%h, got 0x%h.", A, B, instr_name, expected_result, result);
          error = 1'b1;
      end
      
      // Verify expected ZF/NF/VF for ADD/SUB/LW/SW.
      verify_flags(.A(A), .B(B), .ALU_out($signed(expected_result)));
    end
  endtask

  // Task: Verify the reduction unit sum.
  task automatic verify_red_sum(input [15:0] A, input [15:0] B);
    begin
      reg [4:0] expected_first_level_sum[0:3];  // expected first level sums
      reg [5:0] expected_second_level_sum[0:1]; // expected second level sums

      // Get the expected first level sums.
      expected_first_level_sum[3] = $signed(A[15:12]) + $signed(B[15:12]);
      expected_first_level_sum[2] = $signed(A[11:8]) + $signed(B[11:8]);
      expected_first_level_sum[1] = $signed(A[7:4]) + $signed(B[7:4]);
      expected_first_level_sum[0] = $signed(A[3:0]) + $signed(B[3:0]);

      // Get the expected second level sums.
      expected_second_level_sum[1] = $signed(expected_first_level_sum[3]) + $signed(expected_first_level_sum[2]);
      expected_second_level_sum[0] = $signed(expected_first_level_sum[1]) + $signed(expected_first_level_sum[0]);

      // Get the expected sum.
      expected_result = $signed(expected_second_level_sum[1]) + $signed(expected_second_level_sum[0]);

      // Validate that the result is the expected result.
      if ($signed(result) !== $signed(expected_result)) begin
          $display("ERROR: A: 0x%h, B: 0x%h, Mode: %s. Reduction Sum expected 0x%h, got 0x%h.", A, B, instr_name, expected_result, result);
          error = 1'b1;
      end

      // Verify flags for RED sum.
      verify_flags(.A(A), .B(B), .ALU_out(expected_result));
    end
  endtask

  // Function to calculate the expected ROR result.
  function [15:0] expected_ror;
    input [15:0] data;
    input [3:0] shift_val;
    integer i;
    reg [15:0] result;
    begin
      result = data;
      // Perform the shift for each shift amount (0 to 15 bits)
      for (i = 0; i < shift_val; i = i + 1) begin
        result = {result[0], result[15:1]}; // Rotate right by 1 bit
      end
      expected_ror = result;
    end
  endfunction

    // Task: Verify the reduction unit sum.
  task automatic verify_shift(input [15:0] A, input [15:0] B);
    begin
      // Expected result and for SLL/SRA/ROR.
      if (stim_op === 4'h4)
        expected_result = A << B[3:0];
      else if (stim_op === 4'h5)
        expected_result = $signed(A) >>> B[3:0];
      else if (stim_op === 4'h6)
        expected_result = expected_ror(.data(A), .shift_val(B[3:0]));

      // Validate that the result is the expected result.
      if ($signed(result) !== $signed(expected_result)) begin
          $display("ERROR: A: 0x%h, B: 0x%h, Mode: %s. Shifted result expected 0x%h, got 0x%h.", A, B, instr_name, expected_result, result);
          error = 1'b1;
      end

      // Verify flags for shift.
      verify_flags(.A(A), .B(B), .ALU_out(expected_result));
    end
  endtask

  // Task: Check for positive or negative overflow for each 4-bit sub-word.
  task automatic check_overflow(input [15:0] A, input [15:0] B, output reg pos_overflow[0:3], output reg neg_overflow[0:3]);
    begin
      // Declare the sum variables for each nibble addition.
      reg [3:0] sum; // 4 bits to store the result of adding two 4-bit nibbles

      // Check overflow for each 4-bit sub-word (nibble)
      // Checking the sum and determining whether the overflow is positive or negative.

      // Check for overflow in the MSB nibble.
      sum = A[15:12] + B[15:12];
      if (~A[15] & ~B[15]) begin  // Both operands are positive
          // If sum[3] (sign bit) is 1, it means positive overflow occurred
          if (sum[3]) 
              pos_overflow[3] = 1;  // Positive overflow
          else
              pos_overflow[3] = 0;  // No Positive overflow
          neg_overflow[3] = 0;  // No negative overflow
      end else if (A[31] & B[15]) begin  // Both operands are negative 
          // If sum[3] (sign bit) is 0, it means negative overflow occurred
          if (~sum[3]) 
              neg_overflow[3] = 1;  // Negative overflow
          else
              neg_overflow[3] = 0;  // No negative overflow
          pos_overflow[3] = 0;  // No positive overflow
      end else begin  // Case when operands have different signs (no overflow expected)
          pos_overflow[3] = 0;  // No positive overflow
          neg_overflow[3] = 0;  // No negative overflow
      end

      // Check for overflow in the second MSB nibble
      sum = A[11:8] + B[11:8];
      if (~A[11] & ~B[11]) begin  // Both operands are positive
          // If sum[3] (sign bit) is 1, it means positive overflow occurred
          if (sum[3]) 
              pos_overflow[2] = 1;  // Positive overflow
          else
              pos_overflow[2] = 0;  // No Positive overflow
          neg_overflow[2] = 0;  // No negative overflow
      end else if (A[11] & B[11]) begin  // Both operands are negative
          // If sum[3] (sign bit) is 0, it means negative overflow occurred
          if (~sum[3]) 
              neg_overflow[2] = 1;  // Negative overflow
          else
              neg_overflow[2] = 0;  // No negative overflow
          pos_overflow[2] = 0;  // No positive overflow
      end else begin  // Case when operands have different signs (no overflow expected)
          pos_overflow[2] = 0;  // No positive overflow
          neg_overflow[2] = 0;  // No negative overflow
      end

      // Check for overflow in the second LSB nibble
      sum = A[7:4] + B[7:4];
      if (~A[7] & ~B[7]) begin  // Both operands are positive
          // If sum[3] (sign bit) is 1, it means positive overflow occurred
          if (sum[3]) 
              pos_overflow[1] = 1;  // Positive overflow
          else
              pos_overflow[1] = 0;  // No Positive overflow
          neg_overflow[1] = 0;  // No negative overflow
      end else if (A[7] & B[7]) begin  // Both operands are negative
          // If sum[3] (sign bit) is 0, it means negative overflow occurred
          if (~sum[3]) 
              neg_overflow[1] = 1;  // Negative overflow
          else
              neg_overflow[1] = 0;  // No negative overflow
          pos_overflow[1] = 0;  // No positive overflow
      end else begin  // Case when operands have different signs (no overflow expected)
          pos_overflow[1] = 0;  // No positive overflow
          neg_overflow[1] = 0;  // No negative overflow
      end

      // Check for overflow in the LSB nibble
      sum = A[3:0] + B[3:0];
      if (~A[3] & ~B[3]) begin  // Both operands are positive 
          // If sum[3] (sign bit) is 1, it means positive overflow occurred
          if (sum[3]) 
              pos_overflow[0] = 1;  // Positive overflow
          else
              pos_overflow[0] = 0;  // No Positive overflow
          neg_overflow[0] = 0;  // No negative overflow
      end else if (A[3] & B[3]) begin  // Both operands are negative
          // If sum[3] (sign bit) is 0, it means negative overflow occurred
          if (~sum[3]) 
              neg_overflow[0] = 1;  // Negative overflow
          else
              neg_overflow[0] = 0;  // No negative overflow
          pos_overflow[0] = 0;  // No positive overflow
      end else begin  // Case when operands have different signs (no overflow expected)
          pos_overflow[0] = 0;  // No positive overflow
          neg_overflow[0] = 0;  // No negative overflow
      end
    end
  endtask

  // Task: Verify the PADDSB instruction.
  task automatic verify_paddsb_sum(input [15:0] A, input [15:0] B);
      // Apply saturation based on the overflow flags for each nibble in the expected_sum array
    begin
      reg pos_overflow[0:3];
      reg neg_overflow[0:3];
      reg [3:0] expected_sum[0:3];

      // Get the overflow of the sum.
      check_overflow(.A(A), .B(B), .pos_overflow(pos_overflow), .neg_overflow(neg_overflow));

      // Handle Most Significant Nibble (MSN)
      if (pos_overflow[3] === 1) begin
          expected_sum[3] = 4'h7;  // Saturate to max positive value for most significant nibble
      end else if (neg_overflow[3] === 1) begin
          expected_sum[3] = 4'h8;  // Saturate to max negative value for most significant nibble
      end else begin
          expected_sum[3] = stim[31:28] + stim[15:12];  // No overflow, use the actual sum
      end

      // Handle second Most Significant Nibble (MSMN)
      if (pos_overflow[2] === 1) begin
          expected_sum[2] = 4'h7;  // Saturate to max positive value for second most significant nibble
      end else if (neg_overflow[2] === 1) begin
          expected_sum[2] = 4'h8;  // Saturate to max negative value for second most significant nibble
      end else begin
          expected_sum[2] = stim[27:24] + stim[11:8];  // No overflow, use the actual sum
      end

      // Handle second Least Significant Nibble (LSMN)
      if (pos_overflow[1] === 1) begin
          expected_sum[1] = 4'h7;  // Saturate to max positive value for second least significant nibble
      end else if (neg_overflow[1] === 1) begin
          expected_sum[1] = 4'h8;  // Saturate to max negative value for second least significant nibble
      end else begin
          expected_sum[1] = stim[23:20] + stim[7:4];  // No overflow, use the actual sum
      end

      // Handle Least Significant Nibble (LSN)
      if (pos_overflow[0] === 1) begin
          expected_sum[0] = 4'h7;  // Saturate to max positive value for least significant nibble
      end else if (neg_overflow[0] === 1) begin
          expected_sum[0] = 4'h8;  // Saturate to max negative value for least significant nibble
      end else begin
          expected_sum[0] = stim[19:16] + stim[3:0];  // No overflow, use the actual sum
      end
      
      // Form the expected_PSA_sum.
      expected_result = {expected_sum[3], expected_sum[2], expected_sum[1], expected_sum[0]};

      // Validate that the result is the expected result.
      if ($signed(result) !== $signed(expected_result)) begin
          $display("ERROR: A: 0x%h, B: 0x%h, Mode: %s. Parallel sub word addition expected 0x%h, got 0x%h.", A, B, instr_name, expected_result, result);
          error = 1'b1;
      end

      // Verify flags for PADDSB.
      verify_flags(.A(A), .B(B), .ALU_out(expected_result));
    end
  endtask

  // Initialize the inputs and expected outputs and wait till all tests finish.
  initial begin
    stim = 32'h00000000; // Initialize stimulus
    stim_op = 4'h0; // Initialize opcode
    expected_ZF = 1'b0;                  // initialize expected z_set flag
    expected_VF = 1'b0;                  // initialize expected v_set flag
    expected_NF = 1'b0;                  // initialize expected n_set flag
    expected_result = 16'h0000;          // initialize expected result
    instr_name = "NULL";                 // initialize the instruction name
    addition_operations = 20'h00000; // initialize addition operation count
    subtraction_operations = 20'h00000; // initialize subtraction operation count
    lw_operations = 20'h00000; // initialize load word operation count
    sw_operations = 20'h00000; // initialize store word operation count
    xor_operations = 20'h00000; // initialize xor operation count
    reduction_operations = 20'h00000; // initialize reduction addition count
    asr_operations = 20'h00000; // initialize asr operation count
    ror_operations = 20'h00000; // initialize ror operation count
    sll_operations = 20'h00000; // initialize sll operation count
    paddsb_operations = 20'h00000; // initialize parallel sub-addition count
    nop_operations = 20'h00000; // initialize nop operation count
    error = 1'b0; // initialize error flag

    // Wait to process the change in the input.
    #5;

    // Apply stimulus as 100000 random input vectors.
    repeat (1000000) begin
      stim = $random; // Generate random stimulus
      stim_op = $random & 4'hF; // generate random opcode.

      // Wait to process the change in the input.
      #1;

      // Get the instruction word.
      decode_opcode();

      // Perform the operation based on the opcode
      case(stim_op)
        4'h0, 4'h1, 4'h8, 4'h9: begin 
          // Verify the ADD/SUB/LW/SW sums.
          verify_sum(.A(stim[31:16]), .B(stim[15:0]));

          // Count up the number of successful operations performed.
          if (!error) begin
            if (stim_op === 4'h0)
              addition_operations = addition_operations + 1'b1;
            else if (stim_op === 4'h1)
              subtraction_operations = subtraction_operations + 1'b1;
            else if (stim_op === 4'h8)
              lw_operations = lw_operations + 1'b1;
            else if (stim_op === 4'h9)
              sw_operations = sw_operations + 1'b1;
          end
        end
        4'h2: begin
          // Get the XOR.
          expected_result = stim[31:16] ^ stim[15:0];

          // Validate that the result is the expected result.
          if ($signed(result) !== $signed(expected_result)) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: XOR. Result expected 0x%h, got 0x%h.", stim[31:16], stim[15:0], expected_result, result);
            error = 1'b1;
          end

          // Verify flags for XOR.
          verify_flags(.A(stim[31:16]), .B(stim[15:0]), .ALU_out(expected_result));

          // Count up the number of successful XOR operations performed.
          if (!error)
            xor_operations = xor_operations + 1'b1;
        end
        4'h3: begin
          // Verify the RED sum.
          verify_red_sum(.A(stim[31:16]), .B(stim[15:0]));

          // Count up the number of successful reduction operations performed.
          if (!error)
            reduction_operations = reduction_operations + 1'b1;
        end   
        4'h4, 4'h5, 4'h6: begin
          // Verify the SLL/SRA/ROR output.
          verify_shift(.A(stim[31:16]), .B(stim[15:0]));

          // Count up the number of successful shift operations performed.
          if (!error) begin
            if (stim_op === 4'h4)
              sll_operations = sll_operations + 1'b1;
            else if (stim_op === 4'h5)
              asr_operations = asr_operations + 1'b1;
            else if (stim_op === 4'h6)
              ror_operations = ror_operations + 1'b1;
          end
        end
        4'h7: begin
          // Verify the PADDSB sum.
          verify_paddsb_sum(.A(stim[31:16]), .B(stim[15:0]));

          // Count up the number of successful parallel subword operations performed.
          if (!error)
            paddsb_operations = paddsb_operations + 1'b1;
        end        
        default: begin
          // Validate that the error flag internal to the ALU is set for invalid opcode.
          if (iDUT.error !== 1'b1) begin
            $display("ERROR: A: 0x%h, B: 0x%h, Mode: %s. Error flag expected 0x%h, got 0x%h.", stim[31:16], stim[15:0], instr_name, iDUT.error, 1'h0);
            error = 1'b1;
          end

          // Count up the number of successful nops performed.
          if (!error)
            nop_operations = nop_operations + 1'b1;
        end
      endcase

      // Print out a status message when the error flag is set.
      if (error) begin
          // Print out the total number of operations performed.
          $display("\nTotal operations performed: 0x%h.", 
                  addition_operations + subtraction_operations + 
                  xor_operations + reduction_operations + 
                  asr_operations + ror_operations + 
                  sll_operations + paddsb_operations + 
                  lw_operations + sw_operations + 
                  nop_operations);
          // Print individual operation counts.
          $display("Number of Successful Additions Performed: 0x%h.", addition_operations);
          $display("Number of Successful Subtractions Performed: 0x%h.", subtraction_operations);
          $display("Number of Successful XORs Performed: 0x%h.", xor_operations);
          $display("Number of Successful Reductions Performed: 0x%h.", reduction_operations);
          $display("Number of Successful ASRs Performed: 0x%h.", asr_operations);
          $display("Number of Successful RORs Performed: 0x%h.", ror_operations);
          $display("Number of Successful SLLs Performed: 0x%h.", sll_operations);
          $display("Number of Successful PADDSBs Performed: 0x%h.", paddsb_operations);
          $display("Number of Successful Load Word Operations Performed: 0x%h.", lw_operations);
          $display("Number of Successful Store Word Operations Performed: 0x%h.", sw_operations);
          $display("Number of NOPs Performed: 0x%h.", nop_operations);
          $stop();
      end

      #5; // wait 5 time units before the next iteration
    end

    // Print out the total number of operations performed.
    $display("\nTotal operations performed: 0x%h.", 
            addition_operations + subtraction_operations + 
            xor_operations + reduction_operations + 
            asr_operations + ror_operations + 
            sll_operations + paddsb_operations + 
            lw_operations + sw_operations + 
            nop_operations);
    $display("Number of Successful Additions Performed: 0x%h.", addition_operations);
    $display("Number of Successful Subtractions Performed: 0x%h.", subtraction_operations);
    $display("Number of Successful XORs Performed: 0x%h.", xor_operations);
    $display("Number of Successful Reductions Performed: 0x%h.", reduction_operations);
    $display("Number of Successful ASRs Performed: 0x%h.", asr_operations);
    $display("Number of Successful RORs Performed: 0x%h.", ror_operations);
    $display("Number of Successful SLLs Performed: 0x%h.", sll_operations);
    $display("Number of Successful PADDSBs Performed: 0x%h.", paddsb_operations);
    $display("Number of Successful Load Word Operations Performed: 0x%h.", lw_operations);
    $display("Number of Successful Store Word Operations Performed: 0x%h.", sw_operations);
    $display("Number of NOPs Performed: 0x%h.", nop_operations);


    // If we reached here, it means that all tests passed.
    $display("YAHOO!! All tests passed.");
    $stop();
  end

endmodule

`default_nettype wire // Reset default behavior at the end