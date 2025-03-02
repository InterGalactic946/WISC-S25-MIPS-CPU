package Model_tasks;

  import ALU_tasks::*;
  
  // Task to initialize testbench signals.
  task automatic Initialize(ref logic clk, ref logic rst_n);
    begin
      clk = 1'b0;
      @(negedge clk) rst_n = 1'b0;
      repeat (2) @(posedge clk); // Wait for 2 clock cycles
      @(negedge clk) rst_n = 1'b1; // Deassert reset
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
      instr = instr_memory[pc/2];

      // Display the fetched instruction.
      $display("Model Fetched instruction at PC = 0x%h: 0x%h", pc, instr);
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
      input logic [15:0] instr,        // The instruction to decode
      output logic [3:0] opcode,       // The decoded opcode
      output string instr_name,        // The decoded instruction name
      output logic [3:0] rs,           // The decoded rs
      output logic [3:0] rt,           // The decoded rt
      output logic [3:0] rd,           // The decoded rd
      output logic [15:0] imm,         // The decoded immediate value (signed or unsigned)
      output logic ALUSrc,             // The decoded ALUSrc signal
      output logic MemtoReg,           // The decoded MemtoReg signal
      output logic RegWrite,           // The decoded RegWrite signal
      output logic RegSrc,             // The decoded RegSrc signal
      output logic MemEnable,          // The decoded MemEnable signal
      output logic MemWrite,           // The decoded MemWrite signal
      output logic Branch,             // The decoded Branch signal
      output logic BR,                 // The decoded BR signal
      output logic HLT,                // The decoded HLT signal
      output logic PCS,                // The decoded PCS signal
      output logic [3:0] ALUOp,              // The decoded ALUOp signal
      output logic Z_en,               // The decoded Z flag enable
      output logic NV_en,              // The decoded N/V flag enable
      output logic [2:0] cc            // The decoded condition code (only for B and BR instructions)
  );
      // Decode the opcode and register fields from the instruction
      opcode = instr[15:12];           // 4-bit opcode
      rs = instr[7:4];                 // 4-bit rs
      rt = instr[3:0];                 // 4-bit rt
      rd = instr[11:8];                // 4-bit rd
      ALUSrc = 1'b0;                   // ALUSrc is 0 for register-register operations
      MemtoReg = 1'b0;                 // MemtoReg is 0 for register-register operations
      RegWrite = 1'b1;                 // RegWrite is 1 for all reg instructions
      RegSrc = 1'b0;                   // RegSrc is 0 for all non LLB/LHB instructions
      MemEnable = 1'b0;                // MemEnable is 0 for all non LW/SW instructions
      MemWrite = 1'b0;                 // MemWrite is 0 for all non SW instructions
      Branch = 1'b0;                   // Branch is 0 for all non B instructions
      BR = 1'b0;                       // BR is 0 for all non BR instructions
      HLT = 1'b0;                      // HLT is 0 for all non HLT instructions
      PCS = 1'b0;                      // PCS is 0 for all non PCS instructions
      ALUOp = opcode;                  // ALUOp is the opcode for all instructions
      Z_en = 1'b0;                     // Z flag enable is 0 for all instructions
      NV_en = 1'b0;                    // N/V flag enable is 0 for all instructions
      cc = 3'bxxx;                     // Default condition code (not used)
      imm = 16'h000;                   // Default immediate value

      // Decode the immediate (imm) based on the opcode
      case (opcode)
          4'b0000, 4'b0001: begin  // ADD, SUB (opcode 0, 1, 2, 3, 7)
            Z_en = 1'b1;      // Z flag enable
            NV_en = 1'b1;     // N/V flag enable
          end
          4'b0010: begin  // XOR (opcode 2)
              Z_en = 1'b1;      // Z flag enable
          end
          4'b0100, 4'b0101, 4'b0110: begin  // SLL, SRA, ROR (opcode 4, 5, 6)
              imm = {12'h000, instr[3:0]};  // Least significant 4 bits, zero-extended to 16 bits
              ALUSrc = 1'b1;    // ALUSrc is 1 for shift operations
              Z_en = 1'b1;      // Z flag enable
          end
          4'b0111: begin // PADDSB (opcode 7)
            // Has all the default values.
          end
          4'b1000: begin  // LW (opcode 8)
              imm = {{12{instr[3]}}, instr[3:0]};  // Lower 4 bits, sign-extended to 16 bits
              ALUSrc = 1'b1;    // ALUSrc is 1 for LW
              MemtoReg = 1'b1;  // Memory to register operation
              MemEnable = 1'b1;  // Memory enable
          end
          4'b1001: begin  // SW (opcode 9)
              imm = {{12{instr[3]}}, instr[3:0]};  // Lower 4 bits, sign-extended to 16 bits
              ALUSrc = 1'b1;    // ALUSrc is 1 for SW
              MemtoReg = 1'bx;  // MemtoReg is x for SW operations
              RegWrite = 1'b0;    // No register write
              MemEnable = 1'b1;  // Memory enable
              MemWrite = 1'b1;    // Memory write operation
          end
          4'b1010, 4'b1011: begin  // LLB, LHB (opcode 10, 11)
              imm = {8'h00, instr[7:0]};  // Lower 8 bits, zero-extended to 16 bits
              ALUSrc = 1'b1;    // ALUSrc is 1 for LW
              RegSrc = 1'b1;    // Register source for LLB/LHB
          end
          4'b1100: begin  // Branch instruction (opcode 12)
              imm = {{7{instr[8]}}, instr[8:0]};  // Lower 9 bits, sign-extended to 16 bits
              cc = instr[11:9];  // Extract the condition code for branch (bits 11:9)
              ALUSrc = 1'bx;     // ALUSrc is  a don't care for B instructions
              MemtoReg = 1'bx;  // MemtoReg is x for B operations
              RegWrite = 1'b0;    // No register write
              Branch = 1'b1;     // Branch operation
              RegSrc = 1'bx;     // Register source is x for B operations
          end
          4'b1101: begin  // BR instruction (opcode 13)
              imm = {{7{instr[8]}}, instr[8:0]};  // Lower 9 bits, sign-extended to 16 bits
              ALUSrc = 1'bx;     // ALUSrc is  a don't care for BR instructions
              MemtoReg = 1'bx;  // MemtoReg is x for BR operations
              RegWrite = 1'b0;    // No register write
              Branch = 1'b1;     // Branch operation
              RegSrc = 1'bx;     // Register source is x for B operations
              BR = 1'b1;         // BR instruction (unconditional branch)
              cc = instr[11:9];  // Extract the condition code for BR (bits 11:9)
          end
          4'b1110: begin  // PCS instruction (opcode 14)
              ALUSrc = 1'bx;    // ALUSrc is a don't care for PCS operation
              PCS = 1'b1;       // PCS operation
          end
          4'b1111: begin  // HLT instruction (opcode 15)
              HLT = 1'b1;       // HLT operation
              ALUSrc = 1'bx;   // ALUSrc is 0 for register-register operations
              MemtoReg = 1'bx; // MemtoReg is 0 for non LW operations
              RegWrite = 1'bx; // Register write
              MemEnable = 1'bx;  // Memory enable is off
              MemWrite = 1'bx; // No memory write
              Branch = 1'bx;   // No branch
              RegSrc = 1'bx;   // Register source is 0 for non LLB/LHB operations
          end
          default: begin
              ALUSrc = 1'b0;   // ALUSrc is 0 for register-register operations
              MemtoReg = 1'b0; // MemtoReg is 0 for non LW operations
              RegWrite = 1'b1; // Register write
              MemEnable = 1'b0;  // Memory enable is off
              MemWrite = 1'b0; // No memory write
              Branch = 1'b0;   // No branch
              RegSrc = 1'b0;   // Register source is 0 for non LLB/LHB operations
              BR = 1'b0;       // No BR
              PCS = 1'b0;      // No PCS
              HLT = 1'b0;      // No HLT
              ALUOp = opcode;  // ALUOp is the opcode for all instructions
              Z_en = 1'b0;     // Z flag enable is off
              NV_en = 1'b0;    // N/V flag enable is off
              imm = 16'h0000;  // Default case if opcode is not recognized
              cc = 3'bxxx;     // Default condition code don't care
          end
      endcase

      // Decode the instruction name.
      decode_opcode(.opcode(opcode), .instr_name(instr_name));  // Decode the opcode to instruction name

      // Display the decoded information (including condition code).
      display_decoded_info(.opcode(opcode), .instr_name(instr_name), .rs(rs), .rt(rt), .rd(rd), .imm(imm), .cc(cc));
  endtask


  // Display the decoded information based on instruction type
  task automatic display_decoded_info(input logic [3:0] opcode, input string instr_name, input logic [3:0] rs, input logic [3:0] rt, input logic [3:0] rd, input logic [15:0] imm, input logic [2:0] cc);
      begin
          case (opcode)
              4'h0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7: // Instructions with 2 registers (like ADD, SUB, XOR, etc.)
                  $display("Model Decoded instruction: Opcode = 0b%4b, Instr: %s, rs = 0x%h, rt = 0x%h, rd = 0x%h.", opcode, instr_name, rs, rt, rd);
              4'h8, 4'h9: // LW and SW have an immediate but no rt register
                  $display("Model Decoded instruction: Opcode = 0b%4b, Instr: %s, rs = 0x%h, rd = 0x%h, imm = 0x%h.", opcode, instr_name, rs, rd, imm);
              4'hA, 4'hB: // LLB and LHB have an immediate but no rt register
                  $display("Model Decoded instruction: Opcode = 0b%4b, Instr: %s, rd = 0x%h, imm = 0x%h.", opcode, instr_name, rd, imm);
              4'hC: // B instruction does not have registers like `rs`, `rt`, or `rd`
                  $display("Model Decoded instruction: Opcode = 0b%4b, Instr: %s, CC: 0b%3b, imm = 0x%h.", opcode, instr_name, cc, imm);
              4'hD: // BR instruction does not have registers like `rt`, or `rd`. It only has a source register `rs`.
                  $display("Model Decoded instruction: Opcode = 0b%4b, Instr: %s, CC: 0b%3b, rs = 0x%h.", opcode, instr_name, cc, rs); 
              4'hE: // (PCS) does not have registers like `rs`, `rt`. It only has a destination register `rd`.
                  $display("Model Decoded instruction: Opcode = 0b%4b, Instr: %s, rd = 0x%h.", opcode, instr_name, rd);
              default: // HLT/Invalid opcode
                  $display("Model Decoded instruction: Opcode = 0b%4b, Instr: %s.", opcode, instr_name);
          endcase
      end
  endtask


  // Task to execute an instruction
  task automatic ExecuteInstruction(input logic [3:0] opcode,
                                      input string instr_name,
                                      input logic signed [15:0] Input_A,
                                      input logic signed [15:0] Input_B,
                                      output logic signed [15:0] result,
                                      output logic Z_set,
                                      output logic N_set,
                                      output logic V_set);
    begin
      logic expected_pos_overflow, expected_neg_overflow;

      expected_pos_overflow = 1'b0;
      expected_neg_overflow = 1'b0;

      case (opcode)
        4'h0, 4'h1, 4'h8, 4'h9: begin // ADD, SUB, LW, SW
          // ADD or SUB
          if (opcode === 4'h1)
            result = Input_A - Input_B;
          else if (opcode === 4'h0 || opcode === 4'h8 || opcode === 4'h9)
            result = Input_A + Input_B;
          else
            result = 16'h0000; // Default to 0

          // Check for overflow only for ADD and SUB instructions.
          if (opcode[3:1] === 3'h0) begin
            get_overflow(.A(Input_A), .B(Input_B), .opcode(opcode), .result(result), .expected_pos_overflow(expected_pos_overflow), .expected_neg_overflow(expected_neg_overflow));

            // Saturate the result if overflow occurs.
            if (expected_pos_overflow) begin
              result = 16'h7FFF;  // Saturate to maximum positive value
            end else if (expected_neg_overflow) begin
              result = 16'h8000;  // Saturate to maximum negative value
            end
          end
        end
        4'h2: result = Input_A ^ Input_B;      // XOR
        4'h3: get_red_sum(.A(Input_A), .B(Input_B), .expected_sum(result)); // RED
        4'h5, 4'h6, 4'h7: begin
          get_shifted_result(.A(Input_A), .B(Input_B[3:0]), .mode(opcode[1:0]), .expected_result(result)); // SLL/SRA/ROR
        end
        4'h7: get_paddsb_sum(.A(Input_A), .B(Input_B), .expected_result(result)); // PADDSB
        4'hA, 4'hB: get_LB_result(.A(Input_A), .B(Input_B), .mode(opcode[0]), .expected_result(result));    // LLB/LHB
        default: result = 16'h0000;              // Default to 0
      endcase
      
      // Set flags based on the result
      Z_set = (result == 16'h0000);  // Set Z flag if result is zero
      N_set = result[15];            // Set N flag based on the sign bit
      V_set = expected_pos_overflow | expected_neg_overflow;  // Set V flag based on overflow

      $display("Model Executed instruction: Opcode = 0b%4b, Instr: %s, Input_A = 0x%h, Input_B = 0x%h, Result = 0x%h, ZF = 0b%1b, VF = 0b%1b, NF = 0b%1b.", opcode, instr_name, Input_A, Input_B, result, Z_set, V_set, N_set);
    end
  endtask

  // Task to simulate memory access (for LW and SW)
  task automatic AccessMemory(input logic [15:0] addr, input logic [15:0] data_in, output logic [15:0] data_out, input logic MemEnable, input logic MemWrite, ref logic [15:0] data_memory [0:65535]);
    begin
      // Read from memory if mem_read is enabled.
      if (MemEnable && !MemWrite) begin
        data_out = data_memory[addr[15:1]];  // Read from memory
        $display("Model Acessed data memory at address: 0x%h and read data as: 0x%h", addr, data_out);
      end

      // Write to memory if mem_write is enabled.
      if (MemEnable && MemWrite) begin
        data_memory[addr[15:1]] = data_in;  // Write to memory
        $display("Model Acessed data memory at address: 0x%h: and wrote new data as 0x%h", addr, data_in);
      end
    end
  endtask

  // Task to write back the result to the register file.
  task automatic WriteBack(ref logic [15:0] regfile [0:15], input logic [3:0] rd, input logic [15:0] input_data, input logic RegWrite);
    begin
      if (RegWrite) begin
        regfile[rd] = input_data;
        $display("Model Wrote back to register: 0x%h with data: 0x%h", rd, input_data);
      end
    end
  endtask

  // TASK: It determines if the condition code is met based on the flags.
  task DetermineNextPC(input logic Branch, input logic BR, input logic [15:0] Rs,  input logic [2:0] C, input logic [2:0] F, input logic [15:0] imm, input logic [15:0] PC_in, output logic [15:0] next_PC);
  begin
    logic taken; // Branch taken flag
    
    // The branch is taken either unconditionally when C = 3'b111 
    // or when the condition code matches the flag register setting.
    taken = (C === 3'b000) ? ~F[2]               : // Not Equal (Z = 0)
            (C === 3'b001) ?  F[2]               : // Equal (Z = 1)
            (C === 3'b010) ? (~F[2] & ~F[0])     : // Greater Than (Z = N = 0)
            (C === 3'b011) ?  F[0]               : // Less Than (N = 1)
            (C === 3'b100) ? (F[2] | (~F[2] & ~F[0])) : // Greater Than or Equal (Z = 1 or Z = N = 0)
            (C === 3'b101) ? (F[2] | F[0])       : // Less Than or Equal (Z = 1 or N = 1)
            (C === 3'b110) ?  F[1]               : // Overflow (V = 1)
            (C === 3'b111) ?  1'b1               : // Unconditional (always executes)
                            1'b0;                // Default: Condition not met (shouldn't happen if C is valid)
    
    // The expected PC addr is the current PC addr + 2 or PC addr + 2 + (I << 1) if branch is taken, or Rs if BR.
    next_PC = (taken === 1'b1 && Branch === 1'b1) ? ((BR === 1'b1) ? Rs : (PC_in + 16'h0002 + ($signed(imm) <<< 1'b1))) : (PC_in + 16'h0002);
  end
  endtask

endpackage
