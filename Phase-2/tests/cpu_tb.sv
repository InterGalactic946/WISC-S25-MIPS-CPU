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
  
  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  // DUT signals.
  logic clk, rst_n, hlt, pc;

  /* Model memory and register file signals. */
  logic [15:0] regfile [0:15];              // 16x16 Register file
  logic [15:0] inst_memory [0:65535];       // Instruction memory
  logic [15:0] data_memory [0:65535];       // Data memory
  logic [15:0] branch_target_buffer [0:15]; // 16x16 Branch Target Buffer
  logic [1:0] branch_history_table [0:15];  // 4x2 Branch History Table
  logic flag_reg[0:2];                      // 3 (ZF,VF,NF) 1-bit flag register

  /* FETCH stage signals */
  wire [15:0] expected_PC_curr;  // Current PC address
  wire [15:0] expected_PC_next;  // Next PC address
  wire [15:0] expected_PC_inst;  // Instruction at the current PC address
  wire expected_predicted_taken; // Predicted taken signal from the branch history table

  /* IF/ID Pipeline Register signals */
  wire [3:0] IF_ID_PC_curr;   // Pipelined lower 4-bits of current instruction (previous PC) address from the fetch stage
  wire [15:0] IF_ID_PC_next;  // Pipelined next instruction (previous PC_next) address from the fetch stage
  wire [15:0] IF_ID_PC_inst;  // Pipelined instruction word (previous PC_inst) from the fetch stage
  wire IF_ID_predicted_taken; // Pipelined branch prediction (previous predicted_taken) from the fetch stage

  /* DECODE stage signals */
  wire [15:0] branch_target; // Computed branch target address
  wire actual_taken;         // Signal used to determine whether an instruction met condition codes
  wire misprediction;        // Indicates the branch was incorrectly predicted in the fetch stage
  wire Branch;               // Indicates it is a branch instruction
  wire BR;                   // Indicates it is a branch register instruction
  wire [62:0] EX_signals;    // Execute stage control signals
  wire [17:0] MEM_signals;   // Memory stage control signals
  wire [7:0] WB_signals;     // Write-back stage control signals

  /* HAZARD DETECTION UNIT signals */
  wire PC_stall;             // Stall signal for the PC register
  wire IF_ID_stall;          // Stall signal for the IF/ID pipeline register
  wire IF_flush, ID_flush;   // Flush signals for each pipeline register

  /* ID/EX Pipeline Register signals */
  wire [3:0] ID_EX_SrcReg1;        // Pipelined first source register ID from the decode stage
  wire [3:0] ID_EX_SrcReg2;        // Pipelined second source register ID from the decode stage
  wire [15:0] ID_EX_ALU_In1;       // Pipelined first ALU input from the decode stage
  wire [15:0] ID_EX_ALU_imm;       // Pipelined ALU immediate input from the decode stage
  wire [15:0] ID_EX_ALU_In2;       // Pipelined second ALU input from the decode stage
  wire [3:0] ID_EX_ALUOp;          // Pipelined ALU operation code from the decode stage
  wire ID_EX_ALUSrc;               // Pipelined ALU select signal to choose between register/immediate operand from the decode stage
  wire ID_EX_Z_en, ID_EX_NV_en;    // Pipelined enable signals setting the Z, N, and V flags from the decode stage
  wire [17:0] ID_EX_MEM_signals;   // Pipelined Memory stage control signals from the decode stage
  wire [7:0] ID_EX_WB_signals;     // Pipelined Write-back stage control signals from the decode stage
  wire [15:0] ID_EX_PC_next;       // Pipelined next instruction (previous PC_next) address from the fetch stage

  /* EXECUTE stage signals */
  wire [15:0] ALU_out;             // ALU output
  wire ZF, VF, NF;                 // Flag signals

  /* FORWARDING UNIT signals */
  wire [1:0] ForwardA;              // Forwarding signal for the first ALU input (ALU_In1)
  wire [1:0] ForwardB;              // Forwarding signal for the second ALU input (ALU_In2)
  wire ForwardMEM;                  // Forwarding signal for MEM stage to MEM stage

  /* EX/MEM Pipeline Register signals */
  wire [15:0] EX_MEM_ALU_out;      // Pipelined data memory address/arithemtic computation result computed from the execute stage
  wire [3:0] EX_MEM_SrcReg2;       // Pipelined second source register ID from the decode stage
  wire [15:0] EX_MEM_MemWriteData; // Pipelined write data for SW from the decode stage
  wire EX_MEM_MemEnable;           // Pipelined data memory access enable signal from the decode stage
  wire EX_MEM_MemWrite;            // Pipelined data memory write enable signal from the decode stage
  wire [7:0] EX_MEM_WB_signals;    // Pipelined Write-back stage control signals from the decode stage
  wire [15:0] EX_MEM_PC_next;      // Pipelined next instruction (previous PC_next) address from the fetch stage

  /* MEMORY stage signals */
  wire [15:0] MemData;             // Data read from memory
  wire [15:0] MemWriteData;        // Data written to memory

  /* MEM/WB Pipeline Register signals */
  wire [15:0] MEM_WB_MemData; // Pipelined data read from memory from the memory stage
  wire [15:0] MEM_WB_ALU_out; // Pipelined arithemtic computation result computed from the execute stage
  wire [3:0] MEM_WB_reg_rd;   // Pipelined register ID of the destination register from the decode stage
  wire MEM_WB_RegWrite;       // Pipelined write enable to the register file from the decode stage
  wire MEM_WB_MemToReg;       // Pipelined select signal to write data read from memory or ALU result back to the register file
  wire MEM_WB_HLT;            // Pipelined HLT signal from the decode stage (indicates that the HLT instruction, if fetched, entered the WB stage) 
  wire MEM_WB_PCS;            // Pipelined PCS signal from the decode stage (indicates that the PCS instruction, if fetched, entered the WB stage)
  wire [15:0] MEM_WB_PC_next; // Pipelined next instruction (previous PC_next) address from the fetch stage

  /* WRITE_BACK stage signals */
  wire [15:0] RegWriteData;   // Data to write back to the register file

  /* TEST_BENCH signals */
  logic error;                // Error flag for test failures
  //////////////////////////////////////////

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  cpu iDUT (.clk(clk), .rst_n(rst_n), .hlt(hlt), .pc(pc));

  // Task to initialize the testbench.
  task automatic Setup();
    begin
      error = 1'b0; // Reset error flag
      
      // Initialize the testbench.
      $display("\nInitializing CPU Testbench...");

      // Initialize the memories the model CPU needs.
      inst_memory = '{default: 16'h0000};
      data_memory = '{default: 16'h0000};
      regfile = '{default: 16'h0000};
      branch_target_buffer = '{default: 16'h0000};
      branch_history_table = '{default: 2'h0};
      flag_reg = '{default: 1'b0};

      // Initialize the current PC value.
      expected_PC_curr = 16'h0000;

      // Initialize all signals for the testbench.
      Initialize(.clk(clk), .rst_n(rst_n));

      // Verify that the PC is initialized to 0x0000.
			if (pc !== expected_PC_curr) begin
					$display("ERROR: DUT has incorrect PC value after reset. PC: 0x%h does not match expected_PC_curr: 0x%h.", pc, expected_PC_curr);
					error = 1'b1;
			end

      // Load conetents into memory for the CPU model as required if no error.
      if (!error) begin
        // Load instructions into memory for the CPU to execute.
        $readmemh("./tests/instructions.img", inst_memory);

        // Load data into data memory for the CPU to perform memory operations.
        $readmemh("./tests/data.img", data_memory);

        // Load data into branch target buffer for the CPU.
        $readmemh("./tests/data.img", branch_target_buffer);
                
        // Load data into branch history table for the CPU.
        $readmemh("./tests/data.img", branch_history_table);
        
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
            .flag_reg(flag_reg),
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
            $display("HLT instruction encountered. Stopping simulation...\n");
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
