  package Verification_tasks;

  // Task to verify the instruction fetched from the instruction memory.
	task automatic VerifyInstructionFetched(
			input logic [15:0] expected_instr,       // Expected instruction
			input logic [15:0] actual_instr,         // Actual instruction fetched from the DUT
			input logic [15:0] instr_memory [0:65535], // The instruction memory array
			input logic [15:0] expected_pc,        // Expected PC value
			input logic [15:0] pc,                 // Actual PC value
			ref logic error                        // Error flag
	);
			// Verify the PC.
			if (pc !== expected_pc) begin
				$display("ERROR (VerificationInstructionFetched): PC Mismatch after instruction fetch: Expected 0x%h, Found 0x%h.", expected_pc, pc);
				error = 1'b1;
			end

			// Verify the fetched instruction.
			if (actual_instr !== expected_instr) begin
				$display("ERROR (VerificationInstructionFetched): Instruction Mismatch at address 0x%h: Expected 0x%h, Found 0x%h.", pc, expected_instr, actual_instr);
				error = 1'b1;
			end

			// Verify that the instruction fetched matches what is in the instruction memory
			if (instr_memory[pc/2] !== actual_instr) begin
				$display("ERROR (VerificationInstructionFetched): Instruction at PC 0x%h does not match memory: Expected 0x%h, Found 0x%h.", pc, instr_memory[pc/2], actual_instr);
				error = 1'b1;
			end

      // Display the fetched instruction if no errors are found.
      if (!error)
        $display("DUT Fetched instruction at PC = 0x%h: 0x%h", pc, actual_instr);
	endtask

  
  task automatic VerifyControlSignals(
      input  logic [3:0] opcode,
      input  string instr_name,
      input  logic [3:0] rs, rt, rd, // Register IDs are 4 bits
      input  logic [15:0] imm,       // Immediate value is 16 bits
      input  logic ALUSrc, MemtoReg, RegWrite, RegSrc,
      input  logic MemEnable, MemWrite, Branch, BR, HLT, PCS,
      input  logic [3:0] ALUOp,
      input  logic Z_en, NV_en,
      input  logic [3:0] cc,         // Condition codes
      input  logic [3:0] DUT_opcode, // DUT opcode
      input  logic [3:0] DUT_reg_rs, DUT_reg_rt, DUT_reg_rd, // DUT register IDs
      input  logic DUT_ALUSrc, DUT_MemtoReg, DUT_RegWrite, DUT_RegSrc,
      input  logic DUT_MemEnable, DUT_MemWrite, DUT_Branch, DUT_BR, DUT_HLT, DUT_PCS,
      input  logic [3:0] DUT_ALUOp,
      input  logic DUT_Z_en, DUT_NV_en,
      input  logic [3:0] DUT_c_codes, // DUT condition codes
      ref logic error
    );

      // Verify opcode
      if (opcode !== DUT_opcode) begin
        $display("ERROR (Verify Control Signals, Verify Opcode): Opcode = 0b%4b, Instr: %s, Expected opcode = 0b%4b but got 0b%4b", opcode, instr_name, opcode, DUT_opcode);
        error = 1'b1;
      end

      // Verify registers
      if (rs !== DUT_reg_rs) begin
        $display("ERROR (Verify Control Signals, Verify Registers): Opcode = 0b%4b, Instr: %s, Expected rs = 0b%4b, got 0b%4b", opcode, instr_name, rs, DUT_reg_rs);
        error = 1'b1;
      end
      if (rt !== DUT_reg_rt) begin
        $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, Expected rt = 0b%4b, got 0b%4b", opcode, instr_name, rt, DUT_reg_rt);
        error = 1'b1;
      end
      if (rd !== DUT_reg_rd) begin
        $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, Expected rd = 0b%4b, got 0b%4b", opcode, instr_name, rd, DUT_reg_rd);
        error = 1'b1;
      end

      // Verify enable signals.
      if (Z_en !== DUT_Z_en) begin
        $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, Expected rt = 0b%4b, got 0b%4b", opcode, instr_name, Z_en, DUT_Z_en);
        error = 1'b1;
      end
      if (NV_en !== DUT_NV_en) begin
        $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, Expected rd = 0b%4b, got 0b%4b", opcode, instr_name, NV_en, DUT_NV_en);
        error = 1'b1;
      end

      // Control Signals Verification based on opcode
      case(opcode)
        4'h0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7, 4'h8, 4'hA, 4'hB: // ADD/SUB/XOR/RED/SLL/SRA/ROR/PADDSB/LW/LLB/LHB
          begin
            if (ALUSrc !== DUT_ALUSrc) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, ALUSrc mismatch (Expected %b, got %b)", opcode, instr_name, ALUSrc, DUT_ALUSrc);
              error = 1'b1;
            end
            if (MemtoReg !== DUT_MemtoReg) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemtoReg mismatch (Expected %b, got %b)", opcode, instr_name, MemtoReg, DUT_MemtoReg);
              error = 1'b1;
            end
            if (RegWrite !== DUT_RegWrite) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, RegWrite mismatch (Expected %b, got %b)", opcode, instr_name, RegWrite, DUT_RegWrite);
              error = 1'b1;
            end
            if (MemEnable !== DUT_MemEnable) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemEnable mismatch (Expected %b, got %b)", opcode, instr_name, MemEnable, DUT_MemEnable);
              error = 1'b1;
            end
            if (MemWrite !== DUT_MemWrite) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemWrite mismatch (Expected %b, got %b)", opcode, instr_name, MemWrite, DUT_MemWrite);
              error = 1'b1;
            end
            if (Branch !== DUT_Branch) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, Branch mismatch (Expected %b, got %b)", opcode, instr_name, Branch, DUT_Branch);
              error = 1'b1;
            end
            if (RegSrc !== DUT_RegSrc) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, RegSrc mismatch (Expected %b, got %b)", opcode, instr_name, RegSrc, DUT_RegSrc);
              error = 1'b1;
            end
          end
        4'h9: // SW
          begin
            if (ALUSrc !== DUT_ALUSrc) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, ALUSrc mismatch (Expected %b, got %b)", opcode, instr_name, ALUSrc, DUT_ALUSrc);
              error = 1'b1;
            end
            if (MemtoReg !=? DUT_MemtoReg) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemtoReg mismatch (Expected %b, got %b)", opcode, instr_name, MemtoReg, DUT_MemtoReg);
              error = 1'b1;
            end
            if (RegWrite !== DUT_RegWrite) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, RegWrite mismatch (Expected %b, got %b)", opcode, instr_name, RegWrite, DUT_RegWrite);
              error = 1'b1;
            end
            if (MemEnable !== DUT_MemEnable) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemEnable mismatch (Expected %b, got %b)", opcode, instr_name, MemEnable, DUT_MemEnable);
              error = 1'b1;
            end
            if (MemWrite !== DUT_MemWrite) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemWrite mismatch (Expected %b, got %b)", opcode, instr_name, MemWrite, DUT_MemWrite);
              error = 1'b1;
            end
            if (Branch !== DUT_Branch) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, Branch mismatch (Expected %b, got %b)", opcode, instr_name, Branch, DUT_Branch);
              error = 1'b1;
            end
            if (RegSrc !== DUT_RegSrc) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, RegSrc mismatch (Expected %b, got %b)", opcode, instr_name, RegSrc, DUT_RegSrc);
              error = 1'b1;
            end
          end
        4'b1100: // B
          begin
            if (ALUSrc !=? DUT_ALUSrc) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, ALUSrc mismatch (Expected %b, got %b)", opcode, instr_name, ALUSrc, DUT_ALUSrc);
              error = 1'b1;
            end
            if (MemtoReg !=? DUT_MemtoReg) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemtoReg mismatch (Expected %b, got %b)", opcode, instr_name, MemtoReg, DUT_MemtoReg);
              error = 1'b1;
            end
            if (RegWrite !== DUT_RegWrite) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, RegWrite mismatch (Expected %b, got %b)", opcode, instr_name, RegWrite, DUT_RegWrite);
              error = 1'b1;
            end
            if (MemEnable !== DUT_MemEnable) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemEnable mismatch (Expected %b, got %b)", opcode, instr_name, MemEnable, DUT_MemEnable);
              error = 1'b1;
            end
            if (MemWrite !== DUT_MemWrite) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemWrite mismatch (Expected %b, got %b)", opcode, instr_name, MemWrite, DUT_MemWrite);
              error = 1'b1;
            end
            if (Branch !== DUT_Branch) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, Branch mismatch (Expected %b, got %b)", opcode, instr_name, Branch, DUT_Branch);
              error = 1'b1;
            end
            if (RegSrc !=? DUT_RegSrc) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, RegSrc mismatch (Expected %b, got %b)", opcode, instr_name, RegSrc, DUT_RegSrc);
              error = 1'b1;
            end
          end
        4'b1101: // BR
          begin
            if (ALUSrc !=? DUT_ALUSrc) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, ALUSrc mismatch (Expected %b, got %b)", opcode, instr_name, ALUSrc, DUT_ALUSrc);
              error = 1'b1;
            end
            if (MemtoReg !=? DUT_MemtoReg) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemtoReg mismatch (Expected %b, got %b)", opcode, instr_name, MemtoReg, DUT_MemtoReg);
              error = 1'b1;
            end
            if (RegWrite !== DUT_RegWrite) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, RegWrite mismatch (Expected %b, got %b)", opcode, instr_name, RegWrite, DUT_RegWrite);
              error = 1'b1;
            end
            if (MemEnable !== DUT_MemEnable) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemEnable mismatch (Expected %b, got %b)", opcode, instr_name, MemEnable, DUT_MemEnable);
              error = 1'b1;
            end
            if (MemWrite !== DUT_MemWrite) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemWrite mismatch (Expected %b, got %b)", opcode, instr_name, MemWrite, DUT_MemWrite);
              error = 1'b1;
            end
            if (Branch !== DUT_Branch) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, Branch mismatch (Expected %b, got %b)", opcode, instr_name, Branch, DUT_Branch);
              error = 1'b1;
            end
            if (RegSrc !== DUT_RegSrc) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, RegSrc mismatch (Expected %b, got %b)", opcode, instr_name, RegSrc, DUT_RegSrc);
              error = 1'b1;
            end
            if (BR !== DUT_BR) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, RegSrc mismatch (Expected %b, got %b)", opcode, instr_name, BR, DUT_BR);
              error = 1'b1;
            end
          end
        4'b1110: // PCS
          begin
            if (ALUSrc !=? DUT_ALUSrc) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, ALUSrc mismatch (Expected %b, got %b)", opcode, instr_name, ALUSrc, DUT_ALUSrc);
              error = 1'b1;
            end
            if (MemtoReg !== DUT_MemtoReg) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemtoReg mismatch (Expected %b, got %b)", opcode, instr_name, MemtoReg, DUT_MemtoReg);
              error = 1'b1;
            end
            if (RegWrite !== DUT_RegWrite) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, RegWrite mismatch (Expected %b, got %b)", opcode, instr_name, RegWrite, DUT_RegWrite);
              error = 1'b1;
            end
            if (MemEnable !== DUT_MemEnable) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemEnable mismatch (Expected %b, got %b)", opcode, instr_name, MemEnable, DUT_MemEnable);
              error = 1'b1;
            end
            if (MemWrite !== DUT_MemWrite) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemWrite mismatch (Expected %b, got %b)", opcode, instr_name, MemWrite, DUT_MemWrite);
              error = 1'b1;
            end
            if (Branch !== DUT_Branch) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, Branch mismatch (Expected %b, got %b)", opcode, instr_name, Branch, DUT_Branch);
              error = 1'b1;
            end
            if (RegSrc !== DUT_RegSrc) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, RegSrc mismatch (Expected %b, got %b)", opcode, instr_name, RegSrc, DUT_RegSrc);
              error = 1'b1;
            end
          end
        4'b1111: // HLT
          begin
            if (ALUSrc !=? DUT_ALUSrc) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, ALUSrc mismatch (Expected %b, got %b)", opcode, instr_name, ALUSrc, DUT_ALUSrc);
              error = 1'b1;
            end
            if (MemtoReg !=? DUT_MemtoReg) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemtoReg mismatch (Expected %b, got %b)", opcode, instr_name, MemtoReg, DUT_MemtoReg);
              error = 1'b1;
            end
            if (RegWrite !=? DUT_RegWrite) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, RegWrite mismatch (Expected %b, got %b)", opcode, instr_name, RegWrite, DUT_RegWrite);
              error = 1'b1;
            end
            if (MemEnable !=? DUT_MemEnable) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemEnable mismatch (Expected %b, got %b)", opcode, instr_name, MemEnable, DUT_MemEnable);
              error = 1'b1;
            end
            if (MemWrite !=? DUT_MemWrite) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, MemWrite mismatch (Expected %b, got %b)", opcode, instr_name, MemWrite, DUT_MemWrite);
              error = 1'b1;
            end
            if (Branch !=? DUT_Branch) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, Branch mismatch (Expected %b, got %b)", opcode, instr_name, Branch, DUT_Branch);
              error = 1'b1;
            end
            if (RegSrc !=? DUT_RegSrc) begin
              $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, RegSrc mismatch (Expected %b, got %b)", opcode, instr_name, RegSrc, DUT_RegSrc);
              error = 1'b1;
            end
          end
        // Further cases would follow with this same format
        default: begin
          $display("ERROR (Verify Control Signals): Opcode = 0b%4b, Instr: %s, Unrecognized Opcode", opcode, instr_name);
          error = 1'b1;
        end
      endcase
  endtask




  // Display the decoded information based on instruction type
  task automatic display_decoded_info(input logic [3:0] opcode, input string instr_name, input logic [3:0] rs, input logic [3:0] rt, input logic [3:0] rd, input logic [15:0] imm, input logic [2:0] cc);
      begin
          case (opcode)
              4'h0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7: // Instructions with 2 registers (like ADD, SUB, XOR, etc.)
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s, rs = 0x%h, rt = 0x%h, rd = 0x%h.", opcode, instr_name, rs, rt, rd);
              4'h8, 4'h9: // LW and SW have an immediate but no rt register
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s, rs = 0x%h, rd = 0x%h, imm = 0x%h.", opcode, instr_name, rs, rd, imm);
              4'hA, 4'hB: // LLB and LHB have an immediate but no rt register
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s, rd = 0x%h, imm = 0x%h.", opcode, instr_name, rd, imm);
              4'hC: // B instruction does not have registers like `rs`, `rt`, or `rd`
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s, CC: 0b%3b, imm = 0x%h.", opcode, instr_name, cc, imm);
              4'hD: // BR instruction does not have registers like `rt`, or `rd`. It only has a source register `rs`.
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s, CC: 0b%3b, rs = 0x%h.", opcode, instr_name, cc, rs); 
              4'hE: // (PCS) does not have registers like `rs`, `rt`. It only has a destination register `rd`.
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s, rd = 0x%h.", opcode, instr_name, rd);
              default: // HLT/Invalid opcode
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s.", opcode, instr_name);
          endcase
      end
  endtask

 // Task to verify the ALU operands.
 task automatic VerifyALUOperands(
    input  string instr_name,
    input  logic [15:0] Input_A,  // Expected Input A operand
    input  logic [15:0] Input_B,  // Expected Input B operand
    input  logic [15:0] ALU_Input_A, // ALU's internal Input_A signal
    input  logic [15:0] ALU_Input_B, // ALU's internal Input_B signal
    ref logic error
  );
    // Verify operand A
    if (Input_A !== ALU_Input_A) begin
        $display("ERROR (VerifyALUOperands): Instr: %s, Expected Input_A = 0x%h, but got 0x%h", instr_name, Input_A, ALU_Input_A);
        error = 1'b1;
    end

    // Verify operand B
    if (Input_B !== ALU_Input_B) begin
        $display("ERROR (VerifyALUOperands): Instr: %s, Expected Input_B = 0x%h, but got 0x%h", instr_name, Input_B, ALU_Input_B);
        error = 1'b1;
    end
 endtask

  // Task to verify the ALU operation result and flags.
  task automatic VerifyExecutionResult(
      input  string instr_name,          // Instruction name
      input  logic [15:0] opcode,        // Opcode for additional context
      input  logic [15:0] result,        // Expected result of the ALU operation
      input  logic Z_set,                // Expected value of the Z flag
      input  logic N_set,                // Expected value of the N flag
      input  logic V_set,                // Expected value of the V flag
      input  logic [15:0] Input_A,       // Input A operand
      input  logic [15:0] Input_B,       // Input B operand
      input  logic [15:0] ALU_Out,       // ALU output (result)
      input  logic ALU_Z,                // Actual Z flag output from ALU
      input  logic ALU_N,                // Actual N flag output from ALU
      input  logic ALU_V,                // Actual V flag output from ALU
      ref logic error                    // Error flag
  );

      // Verify ALU result
      if (result !== ALU_Out) begin
          $display("ERROR (VerifyExecutionResult): Instr: %s, Opcode: 0b%4b, Expected result = 0x%h, but got 0x%h", instr_name, opcode, result, ALU_Out);
          error = 1'b1;
      end

      // Verify Z flag
      if (Z_set !== ALU_Z) begin
          $display("ERROR (VerifyExecutionResult): Instr: %s, Opcode: 0b%4b, Expected Z flag = %b, but got %b", instr_name, opcode, Z_set, ALU_Z);
          error = 1'b1;
      end

      // Verify N flag
      if (N_set !== ALU_N) begin
          $display("ERROR (VerifyExecutionResult): Instr: %s, Opcode: 0b%4b, Expected N flag = %b, but got %b", instr_name, opcode, N_set, ALU_N);
          error = 1'b1;
      end

      // Verify V flag
      if (V_set !== ALU_V) begin
          $display("ERROR (VerifyExecutionResult): Instr: %s, Opcode: 0b%4b, Expected V flag = %b, but got %b", instr_name, opcode, V_set, ALU_V);
          error = 1'b1;
      end

      // Display the execution result if no errors are found.
      if (!error)
          $display("DUT Executed instruction: Opcode = 0b%4b, Instr: %s, Input_A = 0x%h, Input_B = 0x%h, Result = 0x%h, ZF = 0b%1b, VF = 0b%1b, NF = 0b%1b.", 
                  opcode, instr_name, Input_A, Input_B, result, Z_set, V_set, N_set);
  endtask


	// Task to verify if the memory contents match between the model and the CPU's memory.
	task automatic VerifyMemoryAccess(
			input logic [15:0] addr,               // Address to access memory
			input string instr_name,         // Instruction name
      input logic enable,               // Enable flag
      input logic [15:0] data_in,        // Data to write to memory
      input logic wr,                   // Write flag
			ref logic [15:0] model_memory [0:65535],  // Expected data memory model
			ref logic [15:0] mem_unit [0:65535],   // Actual memory in DUT (CPU memory)
			ref logic error                       // Error flag
	);

			// Compare the model memory and the actual memory in the CPU.
      if (enable) begin
        if (!wr) begin
          if (mem_unit[addr] !== model_memory[addr]) begin
              $display("ERROR (VerifyMemoryAccess): Memory Mismatch at address 0x%h: Expected 0x%h, Found 0x%h. Instruction: %s", 
                      addr, model_memory[addr], mem_unit[addr], instr_name);
              error = 1'b1;
          end
          $display("DUT Acessed data memory at address: 0x%h and read data as: 0x%h", addr, mem_unit[addr]);
        end else begin
          $display("DUT attempted to acesss data memory at address: 0x%h: and attempted to write new data as 0x%h", addr, data_in);
        end
      end
	endtask

  // Task to verify flag register.
  task automatic VerifyFlagRegister(
      input  logic [2:0] flag_reg,      // Expected flag register {N, V, Z}
      input  logic [2:0] DUT_flag_reg,  // DUT's actual flag register {N, V, Z}
      ref logic error
  );
  begin
      // Check Z flag (flag_reg[0])
      if (flag_reg[2] !== DUT_flag_reg[2]) begin
          $display("ERROR: Z_flag mismatch. Expected: %b, Found: %b", flag_reg[2], DUT_flag_reg[2]);
          error = 1'b1;
      end
      
      // Check V flag (flag_reg[1])
      if (flag_reg[1] !== DUT_flag_reg[1]) begin
          $display("ERROR: V_flag mismatch. Expected: %b, Found: %b", flag_reg[1], DUT_flag_reg[1]);
          error = 1'b1;
      end
      
      // Check N flag (flag_reg[2])
      if (flag_reg[0] !== DUT_flag_reg[0]) begin
          $display("ERROR: N_flag mismatch. Expected: %b, Found: %b", flag_reg[0], DUT_flag_reg[0]);
          error = 1'b1;
      end
  end
  endtask

endpackage  