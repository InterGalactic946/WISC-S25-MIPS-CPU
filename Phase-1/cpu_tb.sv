`default_nettype none // Set the default as none to avoid errors

module cpu_tb();

  import tb_tasks::*;

  ///////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  logic clk, rst_n;

  ///////////////////////////////
  // Declare internal signals //
  /////////////////////////////
  logic hlt;
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
  logic MemRead, MemWrite, RegWrite, Branch, BR;
  logic [15:0] reg_data;
  logic [15:0] result;
  logic [15:0] data_memory_output;
  string instr_name;
  logic [2:0] cc;            // Condition code for branch instructions
  logic [15:0] regfile [0:15];        // Register file to verify during execution
  logic [15:0] instr_memory [0:1023]; // Instruction Memory to be loaded
  logic [15:0] instr_memory [0:1023]; // Data Memory to be loaded
  logic flag_reg [2:0];               // Flag register to verify during execution
  logic error;                       // Error flag to indicate test failure

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  cpu iDUT (.clk(clk), .rst_n(rst_n), .hlt(hlt), .pc(pc));

  // Task to verify that all memory locations and registers are zero post initialization.
  task VerifyPostInitialization();
      integer addr;
      reg [15:0] data;

      // Verify that the PC is initialized to 0x0000.
      if (pc !== expected_pc) begin
        $display("ERROR: PC not initialized to 0x0000 after reset.");
        error = 1'b1;
      end

      // Verify Data Memory (iDATA_MEM)
      for (addr = 0; addr < 65536; addr = addr + 1) begin
          data = iDUT.iDATA_MEM.mem[addr]; // Accessing memory array
          if (data !== 16'h0000) begin
              $display("ERROR: Data Memory at address %0d: Expected 0x0000, Found 0x%h.", addr, data);
              error = 1'b1;
          end
      end

      // Verify Instruction Memory (iINSTR_MEM)
      for (addr = 0; addr < 65536; addr = addr + 1) begin
          data = iDUT.iINSTR_MEM.mem[addr]; // Accessing memory array
          if (data !== 16'h0000) begin
              $display("ERROR: Instruction Memory at address %0d: Expected 0x0000, Found 0x%h.", addr, data);
              error = 1'b1;
          end
      end

      // Verify Register File (iRF)
      for (addr = 0; addr < 16; addr = addr + 1) begin
          // Set the source registers to each register address
          iDUT.iRF.SrcReg1 = addr;
          iDUT.iRF.SrcReg2 = addr;

          // Read the data from both source registers
          @(posedge clk); // wait for the next clock cycle

          if (iDUT.iRF.SrcData1 !== 16'h0000) begin
              $display("ERROR: Register File Error at register %0d (SrcData1): Expected 0x0000, Found 0x%h", addr, iDUT.iRF.SrcData1);
              error = 1'b1;
          end
          if (iDUT.iRF.SrcData2 !== 16'h0000) begin
              $display("ERROR: Register File Error at register %0d (SrcData2): Expected 0x0000, Found 0x%h", addr, iDUT.iRF.SrcData2);
              error = 1'b1;
          end
      end
  endtask

  // Task to initialize the testbench.
  task automatic Setup();
    begin
      error = 1'b0; // Reset error flag
      regfile = '{default: 16'h0000}; // Initialize all registers to 0x0000
      
      // Initialize the PC to a starting value (e.g., 0)
      $display("Initializing CPU Testbench...");

      // Initialize all signals for the testbench.
      Initialize(.clk(clk), .rst_n(rst_n), .pc(expected_pc));

      // Verify that all memory locations and registers are zero post initialization.
      VerifyPostInitialization();

      // Load instructions into memory for the CPU to execute.
      if (!error) begin
        // Load instructions into memory for the CPU to execute.
        LoadImage("instructions.img", instr_memory);

        // Load instructions into data memory for the CPU to perform memory operations.
        LoadImage("data.img", data_memory);
        
        // Print a message to indicate successful initialization.
        $display("CPU Testbench initialized successfully.");
      end else begin
        $display("ERROR: CPU Testbench initialization failed.");
        $stop();
      end
    end
  endtask

  // Test procedure to apply stimulus and check responses
  initial begin
    ///////////////////////////////
    // Initialize the testbench //
    /////////////////////////////
    Setup();

    // Run the simulation for each instruction in the instruction memory.
    repeat (instr_memory.size) begin
      @(posedge clk); // Wait for the next clock cycle

      // Fetch the current instruction from memory.
      FetchInstruction(.instr_memory(instr_memory), .pc(expected_pc), .instr(instr));

      // Decode the instruction to extract opcode, rs, rt, rd, imm, and cc.
      DecodeInstruction(
        .pc(next_pc),            // Pass next PC value
        .instr(instr),           // Pass instruction to decode
        .instr_name(instr_name), // Pass output for decoded instruction name
        .opcode(opcode),         // Pass output for decoded opcode
        .rs(rs),                 // Pass output for decoded rs
        .rt(rt),                 // Pass output for decoded rt
        .rd(rd),                 // Pass output for decoded rd
        .imm(imm),               // Pass output for decoded immediate value
        .cc(cc)                  // Pass output for decoded condition code
        .Branch(Branch)          // Pass output for branch flag
        .BR(BR)                  // Pass output for branch flag
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .RegWrite(RegWrite)
      );

      // If the HLT instruction is encountered, stop the simulation.
      if (opcode === 4'hF) begin
        $display("HLT instruction encountered. Stopping simulation.");
        $stop();
      end
      
      // Choose the correct operands for the instruction based on the opcode.
      ChooseALUOperands(
        .opcode(opcode), // Pass opcode to choose operands
        .reg_rs(rs),         // Pass source register 1
        .reg_rt(rt),         // Pass source register 2
        .reg_rd(rd),         // Pass destination register
        .imm(imm),       // Pass immediate value
        .regfile(regfile) // Pass register file
        .Input_A(A),
        .Input_B(B)
      );

      // Execute the instruction based on the opcode and operands.
      ExecuteInstruction(
        .opcode(opcode), // Pass opcode to execute
        .instr_name(instr_name), // Pass instruction
        .Input_A(A), // Pass source register 1 value
        .Input_B(B), // Pass source register 2 value
        .result(result), // Pass result of the operation
        .Z_set(flag_reg[2]),
        .V_set(flag_reg[1]),
        .N_set(flag_reg[0])
      );

      // Access the memory based on the opcode and operands.
      AccessMemory(.addr(result), .data_in(regfile[rd]), .data_out(data_memory_output), .mem_read(MemRead), .mem_write(MemWrite), .data_memory(data_memory));

      // Choose ALU_output or memory_output based on the opcode.
      reg_data = (MemRead) ? data_memory_output : ((PCS) ? next_PC : result);

      // Write the result back to the register file based on the opcode and operands.
      WriteBack(.regfile(regfile), .reg_rd(rd), .input_data(reg_data), .wr_enable(RegWrite));

      // Determine the next PC value based on the opcode and operands.
      DetermineNextPC(
        .Branch(Branch), // Pass branch flag
        .BR(BR), // Pass branch flag
        .cc(cc), // Pass condition code
        .Z(flag_reg[2]), // Pass Z flag
        .V(flag_reg[1]), // Pass V flag
        .N(flag_reg[0]), // Pass N flag
        .PC_in(expected_pc), // Pass current PC value 
        .imm(imm), // Pass immediate value
        .next_PC(next_pc)
      );
    end

    // If we reached here, that means all test cases were successful
    $display("YAHOO!! All tests passed.");
    $stop();
  end

  // Generate clock signal with 10 ns period
  always 
    #5 clk = ~clk;
  
  // Expected PC value after each instruction
  always @(posedge clk)
    expected_pc <= next_pc;

endmodule

`default_nettype wire  // Reset default behavior at the end
