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

  // Importing task libraries.
  import Monitor_tasks::*;
  import Verification_tasks::*;

  ///////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  logic clk, rst_n;                  // Clock and reset signals
  logic hlt, expected_hlt;           // Halt signals for execution stop for each DUT and model
  logic [15:0] expected_pc;          // Expected program counter value for verification
  logic [15:0] pc;                   // Current program counter value

  logic [62:0] EX_signals;           // Execute stage control signals
  logic [17:0] MEM_signals;          // Memory stage control signals
  logic [7:0] WB_signals;            // Write-back stage control signals
  logic [62:0] expected_EX_signals;  // Execute stage control signals (expected)
  logic [17:0] expected_MEM_signals; // Memory stage control signals (expected)
  logic [7:0] expected_WB_signals;   // Write-back stage control signals (expected)

  string fetch_msg;                  // Message from the fetch stage.
  string decode_msg;                 // Message from the decode stage.
  string instruction_full_msg;       // Full instruction message from the decode stage.
  string execute_msg;                // Message from the execute stage.
  string mem_msg;                    // Message from the memory stage.
  string wb_msg;                     // Message from the write-back stage.
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  cpu iDUT (
    .clk(clk),
    .rst_n(rst_n),
    .hlt(hlt),
    .pc(pc)
  );

  ////////////////////////
  // Instantiate Model //
  //////////////////////
  cpu_model iMODEL (
    .clk(clk),
    .rst_n(rst_n),
    .hlt(expected_hlt),
    .pc(expected_pc)
  );

  ////////////////////////////////////
  // Instantiate Verification Unit //
  //////////////////////////////////
   Verification_Unit iVERIFY (
    .clk(clk),
    .rst_n(rst_n),
    .fetch_msg(fetch_msg),
    .decode_msg(decode_msg),
    .instruction_full_msg(instruction_full_msg),
    .execute_msg(execute_msg),
    .mem_msg(mem_msg),
    .wb_msg(wb_msg)
  );

  // Test procedure to apply stimulus and check responses.
  initial begin
    // Initialize the testbench
    Initialize(.clk(clk), .rst_n(rst_n));

    // Setup the testbench environment.
    $display("\n");

    // Run the simulation for each instruction in the instruction memory until HLT reaches WB.
    TimeoutTask(.sig(hlt), .clk(clk), .clks2wait(1000000), .signal("HLT"));

    // Wait for 2 cycles to print last actual instruction and HLT.
    repeat (2) @(posedge clk);
    
    $display("CPU halted due to HLT instruction.\n");

    // If we reached here, that means all test cases were successful.
    $display("YAHOO!! All tests passed.");
    $stop();
  end


  // Dump contents of Data memory, and Regfile contents.
  always_ff @(negedge clk) begin
      if (rst_n) begin
        // Log data memory contents.
        if (iDUT.MemEnable || hlt) begin
          log_data_dump(
              .model_data_mem(iMODEL.iDATA_MEM.data_memory),     
              .dut_data_mem(iDUT.iDATA_MEM.mem)          
          );
        end
        
        // Log the regfile contents.
        if (iDUT.RegWrite || hlt) begin
          log_regfile_dump(.regfile(iMODEL.iRF.regfile));
        end
      end
  end


  // Always block for verify_FETCH stage.
  always_ff @(posedge clk) begin
      if (rst_n) begin
        // Local variable.
        string ftch_msg;

        // Verify FETCH stage logic.
        verify_FETCH(
              .PC_next(iDUT.nxt_pc), 
              .expected_PC_next(iMODEL.nxt_pc), 
              .PC_inst(iDUT.pc_inst), 
              .expected_PC_inst(iMODEL.pc_inst), 
              .PC_curr(pc), 
              .expected_PC_curr(expected_pc), 
              .fetch_msg(ftch_msg)
        );

        fetch_msg = {"|", ftch_msg};

    end
  end


  ////////////////////////////////////////////////
  // Package each stage's control signals (DUT) //
  ////////////////////////////////////////////////
  // Package the execute stage control signals.
  assign EX_signals = {iDUT.SrcReg1, iDUT.SrcReg2, iDUT.ALU_In1, iDUT.ALU_imm, iDUT.ALU_In2, iDUT.ALUOp, iDUT.ALUSrc, iDUT.Z_en, iDUT.NV_en};

  // Package the memory stage control signals.
  assign MEM_signals = {iDUT.SrcReg2_data, iDUT.MemEnable, iDUT.MemWrite};

  // Package the write back stage control signals.
  assign WB_signals = {iDUT.reg_rd, iDUT.RegWrite, iDUT.MemToReg, iDUT.HLT, iDUT.PCS};
  /////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////
  // Package each stage's control signals (Model)  //
  ///////////////////////////////////////////////////
  // Package the execute stage control signals.
  assign expected_EX_signals = {iMODEL.SrcReg1, iMODEL.SrcReg2, iMODEL.ALU_In1, iMODEL.ALU_imm, iMODEL.ALU_In2, iMODEL.ALUOp, iMODEL.ALUSrc, iMODEL.Z_en, iMODEL.NV_en};

  // Package the memory stage control signals.
  assign expected_MEM_signals = {iMODEL.SrcReg2_data, iMODEL.MemEnable, iMODEL.MemWrite};

  // Package the write back stage control signals.
  assign expected_WB_signals = {iMODEL.reg_rd, iMODEL.RegWrite, iMODEL.MemToReg, iMODEL.HLT, iMODEL.PCS};
  /////////////////////////////////////////////////////////////


  // Always block for verify_DECODE stage
  always_ff @(posedge clk) begin
      if (rst_n) begin
        // Local variable.
        string dcode_msg;

        // Call the verify_DECODE task and get the decode message and full instruction message.
        verify_DECODE(
            .EX_signals(EX_signals),
            .expected_EX_signals(expected_EX_signals),
            .MEM_signals(MEM_signals),
            .expected_MEM_signals(expected_MEM_signals),
            .WB_signals(WB_signals),
            .expected_WB_signals(expected_WB_signals),
            .cc(iDUT.c_codes),
            .flag_reg({iDUT.ZF, iDUT.VF, iDUT.NF}),
            .is_branch(iDUT.Branch),
            .expected_is_branch(iMODEL.Branch),
            .is_BR(iDUT.pc_inst[12]),
            .expected_is_BR(iMODEL.pc_inst[12]),
            .actual_target(iDUT.iPCC.PC_out),
            .expected_actual_target(iMODEL.iPCC.PC_out),
            .actual_taken(iDUT.iPCC.Branch_taken),
            .expected_actual_taken(iMODEL.iPCC.Branch_taken),
            
            .decode_msg(dcode_msg),
            .instruction_full(instruction_full_msg)
          );

        decode_msg = {"|", dcode_msg};

      end
  end


    // Always block for verify_EXECUTE stage.
    always_ff @(posedge clk) begin
      if (rst_n) begin
        // Local variable.
        string ex_msg;

        verify_EXECUTE(
          .Input_A(iDUT.iALU.Input_A),
          .Input_B(iDUT.iALU.Input_B),
          .expected_Input_A(iMODEL.iALU_model.Input_A),
          .expected_Input_B(iMODEL.iALU_model.Input_B),
          .ALU_out(iDUT.ALU_out),
          .Z_set(iDUT.iALU.Z_set),
          .V_set(iDUT.iALU.V_set),
          .N_set(iDUT.iALU.N_set),
          .expected_ALU_out(iMODEL.ALU_out),
          .ZF(iDUT.ZF),
          .NF(iDUT.NF),
          .VF(iDUT.VF),
          .expected_ZF(iMODEL.ZF),
          .expected_VF(iMODEL.VF),
          .expected_NF(iMODEL.NF),
          
          .execute_msg(ex_msg)
        );

        execute_msg = {"|", ex_msg};
      
    end   
  end


  // Always block for verify_MEMORY stage.
  always_ff @(posedge clk) begin
    if (rst_n) begin
      // Local variable.
      string mem_verify_msg;

      verify_MEMORY(
        .MemAddr(iDUT.ALU_out),
        .MemData(iDUT.MemData),
        .expected_MemData(iMODEL.MemData),
        .MemWriteData(iDUT.SrcReg2_data),
        .expected_MemWriteData(iMODEL.SrcReg2_data),
        .MemEnable(iDUT.MemEnable),
        .MemWrite(iDUT.MemWrite),
        
        .mem_verify_msg(mem_verify_msg)
      );
      
      mem_msg = {"|", mem_verify_msg};

    end
  end


  // Always block for verify_WRITEBACK stage.
  always_ff @(posedge clk) begin
    if (rst_n) begin
      // Local variable.
      string wbb_msg;

      verify_WRITEBACK(
        .DstReg(iDUT.reg_rd),
        .RegWrite(iDUT.RegWrite),
        .RegWriteData(iDUT.RegWriteData),
        .expected_RegWriteData(iMODEL.RegWriteData),
        
        .wb_verify_msg(wbb_msg)
      );
      
      wb_msg = {"|", wbb_msg};

    end
  end


  // Generate clock signal with 10 ns period
  always 
    #5 clk = ~clk;

endmodule