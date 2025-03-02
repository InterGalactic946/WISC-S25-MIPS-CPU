`default_nettype none // Set the default as none to avoid errors

module cpu_tb();

  import Model_tasks::*;
  import ALU_tasks::*;
  import Verification_tasks::*;


  ///////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  logic clk, rst_n;

  ///////////////////////////////
  // Declare internal signals //
  /////////////////////////////
  logic hlt;
  logic taken;
  logic [15:0] expected_pc;
  logic [15:0] pc;
  logic [15:0] next_pc;
  logic [15:0] instr;
  logic [3:0] opcode;
  logic [3:0] rs;
  logic [3:0] rt;
  logic [3:0] rd;
  logic [15:0] imm;
  logic [15:0] A, B;
  logic ALUSrc, MemtoReg, RegWrite, RegSrc, MemEnable, MemWrite, Branch, BR, HLT, Z_en, NV_en; // Control signals
  logic [3:0] ALUOp;
  logic [15:0] reg_data;
  logic [15:0] result;
  logic [15:0] data_memory_output;
  string instr_name;
  logic [2:0] cc;            // Condition code for branch instructions
  logic [15:0] regfile [0:15];        // Register file to verify during execution
  reg [15:0] instr_memory [0:65535]; // Instruction Memory to be loaded
  reg [15:0] data_memory [0:65535]; // Data Memory to be loaded
  logic [2:0] flag_reg;               // Flag register to verify during execution
  logic Z_enable, V_enable, N_enable; // Enable flags for updating flag register
  logic Z_set, V_set, N_set;          // Flags to be set based on the result of the operation
  logic PCS;                          // Flag to determine if the next PC is the result of the ALU operation
  logic error;                        // Error flag to indicate test failure

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  cpu iDUT (.clk(clk), .rst_n(rst_n), .hlt(hlt), .pc(pc));

  // Task to initialize the testbench.
  task automatic Setup();
    begin
      error = 1'b0; // Reset error flag
      
      // Initialize the PC to a starting value (e.g., 0)
      $display("Initializing CPU Testbench...");
      instr_memory = '{default: 16'h0000};
      flag_reg = '{default: 3'h0};
      next_pc = 16'h0000;
      expected_pc = 16'h0000;

      // Initialize all signals for the testbench.
      Initialize(.clk(clk), .rst_n(rst_n));

      // Verify that the PC is initialized to 0x0000.
			if (pc !== expected_pc) begin
					$display("ERROR: PC: 0x%h does not match Expected_PC: 0x%h after reset.", pc, expected_pc);
					error = 1'b1;
			end

      // Load instructions into memory for the CPU to execute.
      if (!error) begin
        // Load instructions into memory for the CPU to execute.
        LoadImage("/filespace/s/sjonnalagad2/WISC-S25-MIPS-CPU/Phase-1/instructions.img", instr_memory);

        // Load instructions into data memory for the CPU to perform memory operations.
        LoadImage("/filespace/s/sjonnalagad2/WISC-S25-MIPS-CPU/Phase-1/data.img", data_memory);
        
        // Print a message to indicate successful initialization.
        $display("CPU Testbench initialized successfully.");
      end else begin
        $display("ERROR: CPU Testbench initialization failed.");
        $stop();
      end
    end
  endtask 

  // Test procedure to apply stimulus and check responses.
  initial begin
      ///////////////////////////////
      // Initialize the testbench //
      /////////////////////////////
      Setup();

      // Run the simulation for each instruction in the instruction memory.
      repeat ($size(instr_memory)) @(posedge clk) begin
        // Fetch the current instruction from memory.
        FetchInstruction(.instr_memory(instr_memory), .pc(expected_pc), .instr(instr));

        // Verify that the instruction was fetched correctly.
        VerifyInstructionFetched(
            .expected_instr(instr),      // Expected instruction
            .actual_instr(iDUT.pc_inst),          // Fetched instruction from DUT
            .instr_memory(iDUT.iINSTR_MEM.mem),          // Instruction memory array
            .expected_pc(expected_pc),            // Expected PC value
            .pc(pc),                              // Actual PC value
            .error(error)                         // Error flag
        );

        // Decode the instruction to extract opcode, rs, rt, rd, imm, and cc, and control signals.
        DecodeInstruction(
            .instr(instr),
            .opcode(opcode),
            .instr_name(instr_name),
            .rs(rs),
            .rt(rt),
            .rd(rd),
            .imm(imm),
            .ALUSrc(ALUSrc),
            .MemtoReg(MemtoReg),
            .RegWrite(RegWrite),
            .RegSrc(RegSrc),
            .MemEnable(MemEnable),
            .MemWrite(MemWrite),
            .Branch(Branch),
            .BR(BR),
            .HLT(HLT),
            .PCS(PCS),
            .ALUOp(ALUOp),
            .Z_en(Z_en),
            .NV_en(NV_en),
            .cc(cc)
        );

        // Verify that the control signals are correctly decoded.
        VerifyControlSignals(
            .opcode(opcode),
            .instr_name(instr_name),
            .rs(rs), .rt(rt), .rd(rd),
            .imm(imm),
            .ALUSrc(ALUSrc), .MemtoReg(MemtoReg), .RegWrite(RegWrite), .RegSrc(RegSrc),
            .MemEnable(MemEnable), .MemWrite(MemWrite), .Branch(Branch), .BR(BR),
            .HLT(HLT), .PCS(PCS),
            .ALUOp(ALUOp), .Z_en(Z_en), .NV_en(NV_en), .cc(cc),
            .DUT_opcode(iDUT.opcode),
            .DUT_reg_rs(iDUT.reg_rs), .DUT_reg_rt(iDUT.reg_rt), .DUT_reg_rd(iDUT.reg_rd),
            .DUT_ALUSrc(iDUT.iCC.ALUSrc), .DUT_MemtoReg(iDUT.iCC.MemtoReg),
            .DUT_RegWrite(iDUT.iCC.RegWrite), .DUT_RegSrc(iDUT.iCC.RegSrc),
            .DUT_MemEnable(iDUT.iCC.MemEnable), .DUT_MemWrite(iDUT.iCC.MemWrite),
            .DUT_Branch(iDUT.iCC.Branch), .DUT_BR(iDUT.iPCC.BR),
            .DUT_HLT(iDUT.iCC.HLT), .DUT_PCS(iDUT.iCC.PCS),
            .DUT_ALUOp(iDUT.iCC.ALUOp),
            .DUT_Z_en(iDUT.iCC.Z_en), .DUT_NV_en(iDUT.iCC.NV_en),
            .DUT_c_codes(iDUT.c_codes),
            .error(error)
        );

        // If the HLT instruction is encountered, stop the simulation.
        if (opcode === 4'hF) begin
          if (!hlt) begin
            $display("ERROR: HLT signal not set after HLT instruction.");
            error = 1'b1;
          end else begin
            $display("HLT instruction encountered. Stopping simulation.");
          end
          $stop();
        end
        
        // Choose the correct operands for the instruction based on the opcode.
        ChooseALUOperands(
          .opcode(opcode), // Pass opcode to choose operands
          .reg_rs(rs),         // Pass source register 1
          .reg_rt(rt),         // Pass source register 2
          .reg_rd(rd),         // Pass destination register
          .imm(imm),       // Pass immediate value
          .regfile(regfile), // Pass register file
          .Input_A(A),
          .Input_B(B)
        );

        // Verify that the correct operands were chosen.
        VerifyALUOperands(
            .instr_name(instr_name),
            .Input_A(A),
            .Input_B(B),
            .ALU_Input_A(iDUT.iALU.Input_A), // ALU internal operand A
            .ALU_Input_B(iDUT.iALU.Input_B), // ALU internal operand B
            .error(error)
        );

        // Execute the instruction based on the opcode and operands.
        ExecuteInstruction(
          .opcode(opcode), // Pass opcode to execute
          .instr_name(instr_name), // Pass instruction
          .Input_A(A), // Pass source register 1 value
          .Input_B(B), // Pass source register 2 value
          .result(result), // Pass result of the operation
          .Z_set(Z_set),
          .V_set(V_set),
          .N_set(N_set)
        );

        // Verify the result of the operation.
        VerifyExecutionResult(
            .instr_name(instr_name),
            .opcode(opcode),
            .result(result),
            .Z_set(Z_set),
            .N_set(N_set),
            .V_set(V_set),
            .Input_A(iDUT.iALU.Input_A), // ALU internal operand A
            .Input_B(iDUT.iALU.Input_B), // ALU internal operand B
            .ALU_Out(iDUT.iALU.ALU_Out),  // ALU's result output
            .ALU_Z(iDUT.iALU.Z_set),       // ALU's Z flag
            .ALU_N(iDUT.iALU.N_set),       // ALU's N flag
            .ALU_V(iDUT.iALU.V_set),       // ALU's V flag
            .error(error)
        );

        // Access the memory based on the opcode and operands.
        AccessMemory(.addr(result), .data_in(regfile[rd]), .data_out(data_memory_output), .MemEnable(MemEnable), .MemWrite(MemWrite), .data_memory(data_memory));

        // Verify the memory access operation.
        VerifyMemoryAccess(
            .addr(result),                // Pass the address to access memory
            .enable(MemEnable),           // Pass the memory enable signal
            .data_in(regfile[rd]),        // Pass the data to write to memory
            .instr_name(instr_name),      // Pass the instruction name
            .wr(MemWrite),             // Pass the memory write signal
            .model_memory(data_memory),  // Pass the memory model from DUT
            .mem_unit(iDUT.iDATA_MEM.mem),     // Pass the actual memory from DUT
            .error(error)                 // Pass the error flag
        );

        // Choose ALU_output or memory_output based on the opcode.
        reg_data = (MemtoReg) ? data_memory_output : ((PCS) ? next_pc : result);

        // Write the result back to the register file based on the opcode and operands.
        WriteBack(.regfile(regfile), .rd(rd), .input_data(reg_data), .RegWrite(RegWrite));

        // (Assuming regfile is updated after the write operation).
        if (RegWrite)
          $display("DUT wrote back to register 0x%h with data 0x%h", iDUT.reg_rd, iDUT.RegWriteData);
        
        // Update flag register.
        flag_reg[2] = (Z_en) ? Z_set : 1'b0;
        flag_reg[1] = (NV_en) ? V_set : 1'b0;
        flag_reg[0] = (NV_en) ? N_set : 1'b0;
        
        // Determine the next PC value based on the opcode and operands.
        DetermineNextPC(
          .Branch(Branch), // Pass branch flag
          .BR(BR), // Pass branch flag
          .C(cc), // Pass condition code
          .F(flag_reg), // Pass flag register
          .PC_in(expected_pc), // Pass current PC value 
          .imm(imm), // Pass immediate value
          .next_PC(next_pc),
          .Rs(regfile[rs])
        );

        // Update the PC register with the next PC value.
        expected_pc = next_pc;

        // Stop the simulation if an error is detected.
        if(error) begin
          $stop();
        end

        // Print a new line between instructions.
        $display("\n");
      end

      // If we reached here, that means all test cases were successful
      $display("YAHOO!! All tests passed.");
      $stop();
    end
  
  // Expected register file at the end of each instruction.
  always @(posedge clk)
    if (!rst_n)
      regfile <= '{default: 16'h0000};
    else if (RegWrite)
      regfile[rd] <= reg_data;
  
  // Expected data memory.
  always @(posedge clk)
    if (!rst_n)
      data_memory <= '{default: 16'h0000};
    else if (MemEnable & MemWrite) // Store operation
      data_memory[result/2] <= regfile[rd];

  // Generate clock signal with 10 ns period.
  always 
    #5 clk = ~clk;

endmodule

`default_nettype wire  // Reset default behavior at the end
