  package ALU_tasks;
  
  // Task: Get positive and negative overflow for addition or subtraction.
  task automatic get_overflow(
    input logic signed [15:0] A,        // Operand A (16-bit)
    input logic signed [15:0] B,        // Operand B (16-bit)
    input logic [3:0] opcode,           // Opcode of the instruction
    input logic signed [15:0] result,   // Expected result (ALU result)
    output logic expected_pos_overflow, // Positive overflow flag
    output logic expected_neg_overflow  // Negative overflow flag
  );
    begin
      // Initialize the overflow flags to 0 (no overflow)
      expected_pos_overflow = 1'b0;
      expected_neg_overflow = 1'b0;

      if (opcode === 4'h1) begin
        // Subtraction (stim_op = 4'h1)
        if ((A[15] === 1'b0) && (B[15] === 1'b1) && (result[15] === 1'b1)) begin
          expected_pos_overflow = 1'b1;  // Positive overflow detected (positive - negative giving negative result)
        end else if ((A[15] === 1'b1) && (B[15] === 1'b0) && (result[15] === 1'b0)) begin
          expected_neg_overflow = 1'b1;  // Negative overflow detected (negative - positive giving positive result)
        end
      end else begin
        // Addition (stim_op is not 4'h1)
        // Overflow occurs in addition when both operands have the same sign and the result has a different sign.
        if (~A[15] & ~B[15] & result[15]) begin
          // Case when both operands are positive
          expected_pos_overflow = 1'b1;  // Positive overflow detected
        end else if (A[15] & B[15] & ~result[15]) begin
          // Case when both operands are negative
          expected_neg_overflow = 1'b1;  // Negative overflow detected
        end
      end
    end
  endtask


  // Task: Return the reduction unit sum.
  task automatic get_red_sum(input logic signed [15:0] A, input logic signed [15:0] B, output logic signed [15:0] expected_sum);
    begin
      reg [4:0] expected_first_level_sum[0:3];  // expected first level sums
      reg [5:0] expected_second_level_sum[0:1]; // expected second level sums
      reg [15:0] expected_sum;                  // expected sum

      // Get the expected first level sums.
      expected_first_level_sum[3] = $signed(A[15:12]) + $signed(B[15:12]);
      expected_first_level_sum[2] = $signed(A[11:8]) + $signed(B[11:8]);
      expected_first_level_sum[1] = $signed(A[7:4]) + $signed(B[7:4]);
      expected_first_level_sum[0] = $signed(A[3:0]) + $signed(B[3:0]);

      // Get the expected second level sums.
      expected_second_level_sum[1] = $signed(expected_first_level_sum[3]) + $signed(expected_first_level_sum[2]);
      expected_second_level_sum[0] = $signed(expected_first_level_sum[1]) + $signed(expected_first_level_sum[0]);

      // Get the expected sum.
      expected_sum = $signed(expected_second_level_sum[1]) + $signed(expected_second_level_sum[0]);
    end
  endtask


  // Function to calculate the expected ROR result.
  function [15:0] get_ror(input logic signed [15:0] data, input logic [3:0] shift_val);
    integer i;
    reg [15:0] result;
    begin
      result = data;
      // Perform the shift for each shift amount (0 to 15 bits)
      for (i = 0; i < shift_val; i = i + 1) begin
        result = {result[0], result[15:1]}; // Rotate right by 1 bit
      end
      get_ror = result;
    end
  endfunction


  // Task: Get the shifted result based on the shift mode.
  task automatic get_shifted_result(input logic signed [15:0] A, input logic [15:0] B, input logic [1:0] mode, output logic signed [15:0] expected_result);
    begin
      // Expected result and for SLL/SRA/ROR.
      if (mode === 2'h0)
        expected_result = A << B[3:0];
      else if (mode === 2'h1)
        expected_result = $signed(A) >>> B[3:0];
      else if (mode === 2'h2)
        expected_result = get_ror(.data(A), .shift_val(B[3:0]));
      else
        expected_result = A; // Default to A
    end
  endtask


  // Task: Check for positive or negative overflow for each 4-bit sub-word.
  task automatic check_pad_overflow(input logic signed [15:0] A, input logic signed [15:0] B, output logic pos_overflow[0:3], output logic neg_overflow[0:3]);
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
      end else if (A[15] & B[15]) begin  // Both operands are negative 
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


  // Task: Get the PADDSB sum.
  task automatic get_paddsb_sum(input logic signed [15:0] A, input logic signed [15:0] B, output logic signed [15:0] expected_result);
      // Apply saturation based on the overflow flags for each nibble in the expected_sum array
    begin
      reg pos_overflow[0:3];
      reg neg_overflow[0:3];
      reg [3:0] expected_sum[0:3];

      // Get the overflow of the sum.
      check_pad_overflow(.A(A), .B(B), .pos_overflow(pos_overflow), .neg_overflow(neg_overflow));

      // Handle Most Significant Nibble (MSN)
      if (pos_overflow[3] === 1) begin
          expected_sum[3] = 4'h7;  // Saturate to max positive value for most significant nibble
      end else if (neg_overflow[3] === 1) begin
          expected_sum[3] = 4'h8;  // Saturate to max negative value for most significant nibble
      end else begin
          expected_sum[3] = A[15:12] + B[15:12];  // No overflow, use the actual sum
      end

      // Handle second Most Significant Nibble (MSMN)
      if (pos_overflow[2] === 1) begin
          expected_sum[2] = 4'h7;  // Saturate to max positive value for second most significant nibble
      end else if (neg_overflow[2] === 1) begin
          expected_sum[2] = 4'h8;  // Saturate to max negative value for second most significant nibble
      end else begin
          expected_sum[2] = A[11:8] + B[11:8];  // No overflow, use the actual sum
      end

      // Handle second Least Significant Nibble (LSMN)
      if (pos_overflow[1] === 1) begin
          expected_sum[1] = 4'h7;  // Saturate to max positive value for second least significant nibble
      end else if (neg_overflow[1] === 1) begin
          expected_sum[1] = 4'h8;  // Saturate to max negative value for second least significant nibble
      end else begin
          expected_sum[1] = A[11:8] + B[7:4];  // No overflow, use the actual sum
      end

      // Handle Least Significant Nibble (LSN)
      if (pos_overflow[0] === 1) begin
          expected_sum[0] = 4'h7;  // Saturate to max positive value for least significant nibble
      end else if (neg_overflow[0] === 1) begin
          expected_sum[0] = 4'h8;  // Saturate to max negative value for least significant nibble
      end else begin
          expected_sum[0] = A[3:0] + B[3:0];  // No overflow, use the actual sum
      end
      
      // Form the expected_PSA_sum.
      expected_result = {expected_sum[3], expected_sum[2], expected_sum[1], expected_sum[0]};
    end
  endtask


  // Task: Get the result of the Load Byte (LB) or Load Half Byte (LHB) instruction.
  task automatic get_LB_result(input logic signed [15:0] A, input logic signed [15:0] B, input logic mode, output logic signed [15:0] expected_result);
    begin
      reg [15:0] expected_result; // Expected result for the LB/LHB operation

      // Get the expected result based on the mode (LB or LHB)
      if (mode === 1'b0) begin
        // Load Low Byte (LB)
          expected_result = (A & 16'hFF00) | (B[7:0]);
      end else begin
        // Load High Byte (LHB)
        expected_result = (A & 16'h00FF) | ({B[7:0], 8'h00});
      end
    end
  endtask


  // Task to select ALU operands based on the instruction opcode.
  task automatic ChooseALUOperands(
    input logic [3:0] opcode,         // The opcode for instruction type
    ref logic [15:0] regfile [0:15], // Register file with 16 registers
    input logic [3:0] reg_rs,         // Source register 1 (rs)
    input logic [3:0] reg_rt,         // Source register 2 (rt)
    input logic [3:0] reg_rd,         // Destination register (rd)
    input logic signed [15:0] imm,           // Immediate value
    output logic signed [15:0] Input_A,  // Operand A for ALU
    output logic signed [15:0] Input_B   // Operand B for ALU
);
    begin
        // Determine Input_A based on opcode
        if (opcode === 4'hA || opcode === 4'hB) begin
            // For LLB (opcode A) and LHB (opcode B), Input_A comes from rd
            Input_A = regfile[reg_rd];
        end else begin
            // For all other opcodes, Input_A comes from reg_rs
            Input_A = regfile[reg_rs];
        end

        // Determine Input_B based on opcode
        case (opcode)
            4'h4, 4'h5, 4'h6, 4'h8, 4'h9, 4'hA, 4'hB, 4'hC, 4'hD: begin
                // SLL, SRA, ROR, LW, SW, B, BR, LLB, LHB (opcode 4, 5, 6, 8, 9, A, B, C, D)
                // Input_B comes from the immediate
                Input_B = imm;
            end
            default: begin
                // For all other opcodes, Input_B comes from reg_rt
                Input_B = regfile[reg_rt];
            end
        endcase
    end
  endtask
 
endpackage
