`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////
// cpu_tb.sv: CPU Testbench Module                       //  
//                                                       //
// This module serves as the testbench for the CPU core. //
// It verifies the correct functionality of instruction  //
// fetching, decoding, execution, and memory operations. //
// The testbench initializes memory, loads instructions, //
// and monitors register updates and ALU results. It     //
// also checks branching behavior and halting conditions.//
///////////////////////////////////////////////////////////
module cpu_tb();

  import ALU_tasks::*;
  import Model_tasks::*;
  import Verification_tasks::*;


  ///////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  logic clk, rst_n;

  ///////////////////////////////
  // Declare internal signals //
  /////////////////////////////
  logic hlt;               // Halt signal for execution stop
  logic taken;             // Indicates if branch was taken
  logic [15:0] expected_pc; // Expected program counter value for verification
  logic [15:0] pc;         // Current program counter value
  logic [15:0] next_pc;    // Next program counter value
  logic [15:0] instr;      // Current instruction
  logic [3:0] opcode;      // Instruction opcode
  logic [3:0] rs, rt, rd;  // Source and destination registers
  logic [15:0] imm;        // Immediate value
  logic [15:0] A, B;       // ALU operands
  logic ALUSrc, MemtoReg, RegWrite, RegSrc, MemEnable, MemWrite, Branch, BR, HLT, Z_en, NV_en; // Control signals
  logic [3:0] ALUOp;       // ALU operation
  logic [15:0] reg_data;   // Register data for write
  logic [15:0] result;     // ALU result
  logic [15:0] data_memory_output; // Data memory output
  string instr_name;       // Instruction name for logging
  logic [2:0] cc;          // Condition code for branch
  logic [15:0] regfile [0:15]; // Register file
  reg [15:0] instr_memory [0:65535]; // Instruction memory
  reg [15:0] data_memory [0:65535]; // Data memory
  logic [2:0] flag_reg;    // Flag register
  logic Z_enable, V_enable, N_enable; // Flag enable signals
  logic Z_set, V_set, N_set; // Flags to be set
  logic PCS;               // Flag for ALU-based PC update
  logic error;             // Error flag for test failures

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
      data_memory <= '{default: 16'h0000};
      regfile = '{default: 16'h0000};
      flag_reg = 3'h0;
      next_pc = 16'h0000;
      expected_pc = 16'h0000;

      // Initialize all signals for the testbench.
      Initialize(.clk(clk), .rst_n(rst_n));

      // Verify that the PC is initialized to 0x0000.
			if (pc !== expected_pc) begin
					$display("ERROR: DUT has incorrect PC value after reset. PC: 0x%h does not match Expected_PC: 0x%h..", pc, expected_pc);
					error = 1'b1;
			end

      // Load instructions into memory for the CPU to execute.
      if (!error) begin
        // Load instructions into memory for the CPU to execute.
        LoadImage("./tests/instructions.img", instr_memory);

        // Load instructions into data memory for the CPU to perform memory operations.
        LoadImage("./tests/data.img", data_memory);
        
        // Print a message to indicate successful initialization.
        $display("CPU Testbench initialized successfully.");
        
        // Print a new line.
        $display("\n");
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
            .expected_instr(instr),      
            .actual_instr(iDUT.pc_inst),          
            .instr_memory(iDUT.iINSTR_MEM.mem),          
            .expected_pc(expected_pc),            
            .pc(pc),                              
            .error(error)                        
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
            .Z_en(Z_en),
            .NV_en(NV_en),
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
            .DUT_HLT(iDUT.iCC.HLT), .DUT_PCS(iDUT.iCC.PCS), .DUT_flag_reg({iDUT.ZF, iDUT.VF, iDUT.NF}),
            .DUT_ALUOp(iDUT.iCC.ALUOp),
            .DUT_Z_en(iDUT.iCC.Z_en), .DUT_NV_en(iDUT.iCC.NV_en),
            .DUT_c_codes(iDUT.c_codes),
            .error(error)
        );

        // If the HLT instruction is encountered, stop the simulation.
        if (opcode === 4'hF) begin
          if (hlt !== 1'b1) begin
            $display("ERROR: HLT signal not set after HLT instruction.");
            error = 1'b1;
          end else begin
            $display("HLT instruction encountered. Stopping simulation.\n");
            // If we reached here, that means all test cases were successful
            $display("YAHOO!! All tests passed.");
          end
          $stop();
        end
        
        // Choose the correct operands for the instruction based on the opcode.
        ChooseALUOperands(
          .opcode(opcode), 
          .reg_rs(rs),         
          .reg_rt(rt),         
          .reg_rd(rd),         
          .imm(imm),       
          .regfile(regfile), 
          .Input_A(A),
          .Input_B(B)
        );

        // Verify that the correct operands were chosen.
        VerifyALUOperands(
            .instr_name(instr_name),
            .Input_A(A),
            .Input_B(B),
            .ALU_Input_A(iDUT.iALU.Input_A), 
            .ALU_Input_B(iDUT.iALU.Input_B), 
            .error(error)
        );

        // Execute the instruction based on the opcode and operands.
        ExecuteInstruction(
          .opcode(opcode), 
          .instr_name(instr_name), 
          .Input_A(A), 
          .Input_B(B), 
          .result(result), 
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
            .Input_A(iDUT.iALU.Input_A), 
            .Input_B(iDUT.iALU.Input_B), 
            .ALU_Out(iDUT.iALU.ALU_Out), 
            .ALU_Z(iDUT.iALU.Z_set),     
            .ALU_N(iDUT.iALU.N_set),     
            .ALU_V(iDUT.iALU.V_set),     
            .error(error)
        );

        // Access the memory based on the opcode and operands.
        AccessMemory(.addr(result), .data_in(regfile[rd]), .data_out(data_memory_output), .MemEnable(MemEnable), .MemWrite(MemWrite), .data_memory(data_memory));

        // Verify the memory access operation.
        VerifyMemoryAccess(
            .addr(result),            
            .enable(MemEnable),           
            .DUT_data_in(iDUT.SrcReg2_data),   
            .model_data_in(regfile[rd]),   
            .instr_name(instr_name),      
            .wr(MemWrite),             
            .model_memory(data_memory),  
            .mem_unit(iDUT.iDATA_MEM.mem),     
            .error(error)               
        );

        // Determine the next PC value based on the opcode and operands.
        DetermineNextPC(
          .Branch(Branch), 
          .BR(BR), 
          .C(cc), 
          .F(flag_reg), 
          .PC_in(expected_pc), 
          .imm(imm), 
          .next_PC(next_pc),
          .Rs(regfile[rs]),
          .taken(taken)
        );

        // Verify the next PC based on the branch condition.
        VerifyNextPC(  
            .expected_next_PC(next_pc),  
            .DUT_next_PC(iDUT.iPCC.PC_out),  
            .expected_taken(taken),  
            .DUT_taken(iDUT.iPCC.Branch_taken),  
            .DUT_Branch(iDUT.iPCC.Branch),
            .error(error)  
        );  

        // Choose ALU_output or memory_output based on the opcode.
        reg_data = (MemtoReg) ? data_memory_output : ((PCS) ? next_pc : result);

        // Write the result back to the register file based on the opcode and operands.
        WriteBack(.regfile(regfile), .rd(rd), .input_data(reg_data), .RegWrite(RegWrite));

        // Verifies the write back stage.
        VerifyWriteBack(
          .DUT_reg_rd(iDUT.reg_rd), 
          .RegWrite(RegWrite), 
          .DUT_RegWriteData(iDUT.RegWriteData), 
          .model_reg_rd(rd), 
          .model_RegWriteData(reg_data), 
          .error(error)
        );

        // Update the PC register with the next PC value.
        expected_pc = next_pc;

        // Update Z flag if enabled, otherwise hold.
        flag_reg[2] = (Z_en)  ? Z_set : flag_reg[2];
        // Update V flag if enabled, otherwise hold.  
        flag_reg[1] = (NV_en) ? V_set : flag_reg[1];
        // Update N flag if enabled, otherwise hold.  
        flag_reg[0] = (NV_en) ? N_set : flag_reg[0];

        // Stop the simulation if an error is detected.
        if (error) begin
          $stop();
        end

        // Print a new line between instructions.
        $display("\n");
      end

      // If we reached here, that means all test cases were successful
      $display("YAHOO!! All tests passed.");
      $stop();
    end
  
  // Verify the flag register at the begining of each clock cycle.
  always @(posedge clk) begin
    // Ignore the check on reset.
    if (rst_n) begin
      // Print out the current state of the model's flag register.
      $display("Model flag register state: ZF = 0b%1b, VF = 0b%1b, NF = 0b%1b.", flag_reg[2], flag_reg[1], flag_reg[0]);
      
      // Verify the DUT's flag register at the begining of each cycle.
      VerifyFlagRegister(.flag_reg(flag_reg), .DUT_flag_reg({iDUT.ZF, iDUT.VF, iDUT.NF}), .error(error));
    end
  end

  // Generate clock signal with 10 ns period.
  always 
    #5 clk = ~clk;

endmodule

`default_nettype wire  // Reset default behavior at the end
