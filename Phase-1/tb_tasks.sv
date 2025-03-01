package tb_tasks;

  // Task to initialize testbench signals.
  task automatic Initialize(ref logic clk, ref logic rst_n, ref logic [15:0] pc);
    begin
      clk = 1'b0;
      pc = 16'h0000;
      @(negedge clk) rst_n = 1'b0;
      repeat (2) @(posedge clk); // Wait for 2 clock cycles
      @(negedge clk) rst_n = 1'b1; // Deassert reset
      repeat (10) @(posedge clk); // Allow system to stabilize
    end
  endtask


  // Task to load an image file into memory.
  task automatic LoadImage(input string filename, ref logic [15:0] memory [0:65535]);
    begin
      // Use $readmemh to load the file contents into memory
      $readmemh(filename, memory);
    end
  endtask


  // Task to fetch an instruction from memory.
  task automatic FetchInstruction(ref logic [15:0] instr_memory [0:65535], ref logic [15:0] pc, output logic [15:0] instr);
    begin
      // Fetch instruction from memory at PC
      instr = instr_memory[pc];

      // Display the fetched instruction.
      $display("Fetching instruction at PC = 0x%h: 0x%h", pc, instr);
    end
  endtask


  // Task to decode an instruction and identify its opcode and operands.
  task automatic decode_opcode(input logic [3:0] opcode, output string instr_name);
    begin
        case (opcode)
            4'h0: instr_name = "ADD";     // 0000: Addition
            4'h1: instr_name = "SUB";     // 0001: Subtraction
            4'h2: instr_name = "XOR";     // 0010: Bitwise XOR
            4'h3: instr_name = "RED";     // 0011: Reduction Addition
            4'h4: instr_name = "SLL";     // 0100: Shift Left Logical
            4'h5: instr_name = "SRA";     // 0101: Shift Right Arithmetic
            4'h6: instr_name = "ROR";     // 0110: Rotate Right
            4'h7: instr_name = "PADDSB";  // 0111: Parallel Sub-word Addition
            4'h8: instr_name = "LW";      // 1000: Load Word
            4'h9: instr_name = "SW";      // 1001: Store Word
            4'hA: instr_name = "LLB";     // 1010: Load Low Byte
            4'hB: instr_name = "LHB";     // 1011: Load High Byte
            4'hC: instr_name = "B";       // 1100: Branch (Conditional)
            4'hD: instr_name = "BR";      // 1101: Branch (Unconditional)
            4'hE: instr_name = "PCS";     // 1110: PCS (Program Counter Store)
            4'hF: instr_name = "HLT";     // 1111: Halt
            default: instr_name = "INVALID"; // Invalid opcode
        endcase
    end
  endtask


  // Task to decode an instruction and display the decoded information.
  task automatic DecodeInstruction(
      input logic [15:0] pc,          // The current program counter value
      input logic [15:0] instr,        // The instruction to decode
      output logic [3:0] opcode,       // The decoded opcode
      output string instr_name,        // The decoded instruction name
      output logic [3:0] rs,           // The decoded rs
      output logic [3:0] rt,           // The decoded rt
      output logic [3:0] rd,           // The decoded rd
      output logic [15:0] imm,         // The decoded immediate value (signed or unsigned)
      output logic MemWrite,           // The decoded MemWrite signal
      output logic MemRead,            // The decoded MemRead signal
      output logic RegWrite,           // The decoded RegWrite signal
      output logic Branch,             // The decoded Branch signal
      output logic BR,                 // The decoded BR signal
      output logic [2:0] cc            // The decoded condition code (only for B and BR instructions)
  );
      // Decode the opcode and register fields from the instruction
      opcode = instr[15:12];           // 4-bit opcode
      rs = instr[7:4];                 // 4-bit rs
      rt = instr[3:0];                 // 4-bit rt
      rd = instr[11:8];                // 4-bit rd
      MemRead = 1'b0;                  // Default to no memory read
      MemWrite = 1'b0;                 // Default to no memory write
      RegWrite = 1'b1;                 // Default register write
      Branch = 1'b0;                   // Default to no branch
      BR = 1'b0;                       // Default to B instruction
      cc = 3'b000;                     // Default condition code (not used)

      // Decode the immediate (imm) based on the opcode
      case (opcode)
          4'b0100, 4'b0101, 4'b0110: begin  // SLL, SRA, ROR (opcode 4, 5, 6)
              imm = {12'h000, instr[3:0]};  // Least significant 4 bits, zero-extended to 16 bits
          end
          4'b1000: begin  // LW (opcode 8)
              imm = {{12{instr[3]}}, instr[3:0]};  // Lower 4 bits, sign-extended to 16 bits
              MemRead = 1'b1;    // Memory read operation
          end
          4'b1001: begin  // LW, SW (opcode 8, 9)
              imm = {{12{instr[3]}}, instr[3:0]};  // Lower 4 bits, sign-extended to 16 bits
              MemWrite = 1'b1;    // Memory write operation
              RegWrite = 1'b0;    // No register write
          end
          4'b1010, 4'b1011: begin  // LLB, LHB (opcode 10, 11)
              imm = {8'h00, instr[7:0]};  // Lower 8 bits, zero-extended to 16 bits
          end
          4'b1100: begin  // Branch instruction (opcode 12)
              imm = {{7{instr[8]}}, instr[8:0]};  // Lower 9 bits, sign-extended to 16 bits
              cc = instr[11:9];  // Extract the condition code for branch (bits 11:9)
              Branch = 1'b1;     // Branch operation
              RegWrite = 1'b0;    // No register write
          end
          4'b1101: begin  // BR instruction (opcode 13)
              imm = {{7{instr[8]}}, instr[8:0]};  // Lower 9 bits, sign-extended to 16 bits
              Branch = 1'b1;     // Branch operation
              RegWrite = 1'b0;    // No register write
              cc = instr[11:9];  // Extract the condition code for BR (bits 11:9)
              BR = 1'b1;         // BR instruction (unconditional branch)
          end
          4'b1110: begin  // PCS instruction (opcode 14)
              imm = 16'h0000;  // No immediate value
              rd = pc;         // Store the current PC value in rd
          end
          default: begin
              imm = 16'h0000;  // Default case if opcode is not recognized
              cc = 3'b000;     // Default condition code (not used)
              RegWrite = 1'b1; // Register write
              MemRead = 1'b0;  // No memory read
              MemWrite = 1'b0; // No memory write
              Branch = 1'b0;   // No branch
          end
      endcase

      decode_opcode(.opcode(opcode), .instr_name(instr_name));  // Decode the opcode to instruction name

      // Display the decoded information (including condition code)
      display_decoded_info(.opcode(opcode), .instr_name(instr_name), .rs(rs), .rt(rt), .rd(rd), .imm(imm), .cc(cc));
  endtask

   // TASK: It determines if the condition code is met based on the flags.
  task DetermineNextPC(input logic Branch, input logic BR, input logic [15:0] Rs,  input [2:0] C, input Z, input V, input N, input [15:0] imm, input logic [15:0] PC_in, output [15:0] next_PC);
    // Check if the condition code is invalid.
    if (C === 3'bx || C === 3'bz) begin
        take = 1'b0;  // Set take to 0 as condition is invalid
        error = 1'b1; // Set error flag
        return;       // Exit the task early if C is invalid
    end    
    
    // Determine if the condition is met based on the value of C
    take = (C === 3'b000) ? ~Z                  : // Not Equal (Z = 0)
           (C === 3'b001) ? Z                   : // Equal (Z = 1)
           (C === 3'b010) ? (~Z & ~N)           : // Greater Than (Z = N = 0)
           (C === 3'b011) ? N                   : // Less Than (N = 1)
           (C === 3'b100) ? (Z | (~Z & ~N))     : // Greater Than or Equal (Z = 1 or Z = N = 0)
           (C === 3'b101) ? (Z | N)             : // Less Than or Equal (Z = 1 or N = 1)
           (C === 3'b110) ? V                   : // Overflow (V = 1)
           (C === 3'b111) ? 1'b1                : // Unconditional (always executes)
           1'b0;                                 // Default: Condition not met (shouldn't happen if C is valid)
    
    // The expected PC addr is the current PC addr + 2 or PC addr + 2 + (I << 1) if branch is taken, or Rs if BR.
    next_PC = (take & Branch) ? ((BR) ? Rs : (PC_in + 16'h0002 + ($signed(imm) <<< 1'b1))) : (PC_in + 16'h0002);
  endtask


  // Display the decoded information based on instruction type
  task automatic display_decoded_info(input logic [3:0] opcode, input string instr_name, input logic [3:0] rs, input logic [3:0] rt, input logic [3:0] rd, input logic [15:0] imm, input logic [2:0] cc);
      begin
          case (opcode)
              4'h0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7: // Instructions with 2 registers (like ADD, SUB, XOR, etc.)
                  $display("Decoded instruction: Opcode = 0b%4b, Instr: %s, rs = 0x%h, rt = 0x%h, rd = 0x%h.", opcode, instr_name, rs, rt, rd);
              4'h8, 4'h9: // LW and SW have an immediate but no rt register
                  $display("Decoded instruction: Opcode = 0b%4b, Instr: %s, rs = 0x%h, rd = 0x%h, imm = 0x%h.", opcode, instr_name, rs, rd, imm);
              4'hA, 4'hB: // LLB and LHB have an immediate but no rt register
                  $display("Decoded instruction: Opcode = 0b%4b, Instr: %s, rd = 0x%h, imm = 0x%h.", opcode, instr_name, rd, imm);
              4'hC: // B instruction does not have registers like `rs`, `rt`, or `rd`
                  $display("Decoded instruction: Opcode = 0b%4b, Instr: %s, CC: 0b%3b, imm = 0x%h.", opcode, instr_name, cc, imm);
              4'hD: // BR instruction does not have registers like `rt`, or `rd`. It only has a source register `rs`.
                  $display("Decoded instruction: Opcode = 0b%4b, Instr: %s, CC: 0b%3b, rs = 0x%h.", opcode, instr_name, cc, rs); 
              4'hE: // (PCS) does not have registers like `rs`, `rt`. It only has a destination register `rd`.
                  $display("Decoded instruction: Opcode = 0b%4b, Instr: %s, rd = 0x%h.", opcode, instr_name, rd);
              default: // HLT/Invalid opcode
                  $display("Decoded instruction: Opcode = 0b%4b, Instr: %s.", opcode, instr_name);
          endcase
      end
  endtask


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
          expected_pos_overflow = 1'b1;  // Positive overflow detected (positive - negative giving positive result)
        end else if ((A[15] === 1'b1) && (B[15] === 1'b0) && (result[15] === 1'b0)) begin
          expected_neg_overflow = 1'b1;  // Negative overflow detected (negative - positive giving negative result)
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
  task automatic get_red_sum(input signed [15:0] A, input signed [15:0] B);
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

      return expected_sum;
    end
  endtask

  // Function to calculate the expected ROR result.
  function [15:0] get_ror(input [15:0] data, input [3:0] shift_val;);
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
  task automatic get_shifted_result(input signed [15:0] A, input [15:0] B, input [1:0] mode);
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
      
      // Return the expected result
      return expected_result;
    end
  endtask


  // Task: Check for positive or negative overflow for each 4-bit sub-word.
  task automatic check_pad_overflow(input signed [15:0] A, input signed [15:0] B, output reg pos_overflow[0:3], output reg neg_overflow[0:3]);
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
  task automatic get_paddsb_sum(input signed [15:0] A, input signed [15:0] B);
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
          expected_sum[3] = stim[31:28] + B_operand[15:12];  // No overflow, use the actual sum
      end

      // Handle second Most Significant Nibble (MSMN)
      if (pos_overflow[2] === 1) begin
          expected_sum[2] = 4'h7;  // Saturate to max positive value for second most significant nibble
      end else if (neg_overflow[2] === 1) begin
          expected_sum[2] = 4'h8;  // Saturate to max negative value for second most significant nibble
      end else begin
          expected_sum[2] = stim[27:24] + B_operand[11:8];  // No overflow, use the actual sum
      end

      // Handle second Least Significant Nibble (LSMN)
      if (pos_overflow[1] === 1) begin
          expected_sum[1] = 4'h7;  // Saturate to max positive value for second least significant nibble
      end else if (neg_overflow[1] === 1) begin
          expected_sum[1] = 4'h8;  // Saturate to max negative value for second least significant nibble
      end else begin
          expected_sum[1] = stim[23:20] + B_operand[7:4];  // No overflow, use the actual sum
      end

      // Handle Least Significant Nibble (LSN)
      if (pos_overflow[0] === 1) begin
          expected_sum[0] = 4'h7;  // Saturate to max positive value for least significant nibble
      end else if (neg_overflow[0] === 1) begin
          expected_sum[0] = 4'h8;  // Saturate to max negative value for least significant nibble
      end else begin
          expected_sum[0] = stim[19:16] + B_operand[3:0];  // No overflow, use the actual sum
      end
      
      // Form the expected_PSA_sum.
      expected_result = {expected_sum[3], expected_sum[2], expected_sum[1], expected_sum[0]};

      return expected_result;
    end
  endtask


  // Task: Get the result of the Load Byte (LB) or Load Half Byte (LHB) instruction.
  task automatic get_LB_result(input signed [15:0] A, input signed [15:0] B, input logic mode);
    begin
      // Get the expected result based on the mode (LB or LHB)
      if (mode === 1'b0) begin
        // Load Low Byte (LB)
          expected_result = (A & 16'hFF00) | (B[7:0]);
      end else begin
        // Load High Byte (LHB)
        expected_result = (A & 16'h00FF) | ({B[7:0], 8'h00});
      end

      return expected_result;
    end
  endtask

  // Task to select ALU operands based on the instruction opcode.
  task automatic ChooseOperands(
    input [3:0] opcode,         // The opcode for instruction type
    ref [15:0] regfile [0:15], // Register file with 16 registers
    input [3:0] reg_rs,         // Source register 1 (rs)
    input [3:0] reg_rt,         // Source register 2 (rt)
    input [3:0] reg_rd,         // Destination register (rd)
    input [15:0] imm,           // Immediate value
    output reg [15:0] Input_A,  // Operand A for ALU
    output reg [15:0] Input_B   // Operand B for ALU
);
    begin
        // Determine Input_A based on opcode
        if (opcode == 4'hA || opcode == 4'hB) begin
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


  // Task to execute an instruction
  task automatic ExecuteInstruction(input logic [3:0] opcode, input string instr_name, input signed logic [15:0] Input_A, input signed logic [15:0] Input_B, output logic signed [15:0] result, output logic Z_set, output logic N_set, output logic V_set);
    begin
      logic expected_pos_overflow, expected_neg_overflow;

      case (opcode)
        4'h0, 4'h1, 4'h8, 4'h9: begin // ADD, SUB, LW, SW
          // ADD or SUB
          if (opcode === 4'h1)
            result = Input_A - Input_B;
          else if (opcode === 4'h0)
            result = Input_A + Input_B;
          else if (opcode === 4'h8 || opcode === 4'h9)
            result = (Input_A & 16'hFFFE + {Input_B[14:0], 1'b0}); // Load Word (LW) or Store Word (SW)
          else
            result = 16'h0000; // Default to 0

          // Check for overflow
          get_overflow(.A(Input_A), .B(Input_B), .opcode(opcode), .result(result), .expected_pos_overflow(expected_pos_overflow), .expected_neg_overflow(expected_neg_overflow));

          // Saturate the result if overflow occurs.
          if (expected_pos_overflow) begin
            result = 16'h7FFF;  // Saturate to maximum positive value
          end else if (expected_neg_overflow) begin
            result = 16'h8000;  // Saturate to maximum negative value
          end
        end
        4'h2: result = Input_A ^ Input_B;      // XOR
        4'h3: result = get_red_sum(.A(Input_A), .B(Input_B)); // RED
        4'h5, 4'h6, 4'h7: begin
          result = get_shifted_result(.A(Input_A), .shamt(Input_B[3:0]), .mode(opcode[1:0])); // SLL/SRA/ROR
        end
        4'h7: result = get_paddsb_sum(.A(Input_A), .B(Input_B)); // PADDSB
        4'hA, 4'hB: result = get_LB_result(.A(Input_A), .B(Input_B), .mode(opcode[0]));    // LLB/LHB
        default: result = 16'h0000;              // Default to 0
      endcase
      
      // Set flags based on the result
      Z_set = (result == 16'h0000);  // Set Z flag if result is zero
      N_set = result[15];            // Set N flag based on the sign bit
      V_set = expected_pos_overflow | expected_neg_overflow;  // Set V flag based on overflow

      // Set the flags based on the opcode.
      if (stim_op === 4'h2 || stim_op === 4'h4 || stim_op === 4'h5 || stim_op === 4'h6) begin
        Z_set = zero;
        N_set = 1'b0;
        V_set = 1'b0;
      end else begin
        Z_set = 1'b0;
        N_set = 1'b0;
        V_set = 1'b0;
      end
      
      $display("Executed instruction: Opcode = 0b%4b, Instr: %s, Input_A = 0x%h, Input_B = 0x%h, Result = 0x%h, ZF = 0b%1b, VF = 0b%1b, NF = 0b%1b.", opcode, instr_name, Input_A, Input_B, result, Z_set, V_set, N_set);
    end
  endtask

  // Task to simulate memory access (for LW and SW)
  task automatic AccessMemory(input logic [15:0] addr, input logic [15:0] data_in, output logic [15:0] data_out, input logic mem_read, input logic mem_write, ref logic [15:0] data_memory [0:65535]);
    begin
      // Read from memory if mem_read is enabled.
      if (mem_read) begin
        data_out = memory[addr];  // Read from memory
        $display("Acessed data memory at address: 0x%h and read data as: 0x%h", addr, data_out);
      end

      // Write to memory if mem_write is enabled.
      if (mem_write) begin
        memory[addr] = data_in;   // Write to memory
        $display("Acessed data memory at address: 0x%h: and wrote new data as 0x%h", addr, data_in);
      end
    end
  endtask

  // Task to write back the result to the register file.
  task automatic WriteBack(ref logic [15:0] regfile [0:15], input logic [3:0] rd, input logic [15:0] input_data, input logic wr_enable);
    begin
      if (wr_enable) begin
        regfile[rd] = input_data;  // Write back to register
        $display("Wrote back to register: 0x%h with data: 0x%h", rd, input_data);
      end
    end
  endtask

endpackage
