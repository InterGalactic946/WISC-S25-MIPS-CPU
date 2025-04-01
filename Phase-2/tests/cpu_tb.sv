///////////////////////////////////////////////////////////
// cpu_tb.sv: CPU Testbench Module                       //  
//                                                       //
// This module serves as the testbench for the CPU core. //
// It verifies the correct functionality of instruction //
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
  logic stall;                       // Indicates a stall in the pipeline.
  logic IF_flush;                    // Indicates a flush in the instruction fetch stage. 
  logic expected_IF_flush;           // Expected flush signal for verification.
  logic ID_flush;                    // Indicates a flush in the instruction decode stage.
  logic expected_ID_flush;           // Expected flush signal for verification.
  logic load_to_use_hazard;          // Indicates a load-use hazard in the pipeline.
  logic expected_load_to_use_hazard; // Expected load-use hazard signal for verification.
  logic B_hazard;                    // Indicates a branch hazard in the pipeline.
  logic expected_B_hazard;           // Expected branch hazard signal for verification.
  logic BR_hazard;                   // Indicates a branch register hazard in the pipeline.
  logic expected_BR_hazard;          // Expected branch register hazard signal for verification.
  string fetch_msg;                  // Message from the fetch stage.
  string decode_msg;                 // Message from the decode stage.
  string instruction_full_msg;       // Full instruction message from the decode stage.
  string execute_msg;                // Message from the execute stage.
  string mem_msg;                    // Message from the memory stage.
  string wb_msg;                     // Message from the write-back stage.
  
  /////////////////////////////////////////
  // Make reset active high for modules //
  ///////////////////////////////////////
  assign rst = ~rst_n;

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
    .wb_msg(wb_msg),
    .stall(stall), .hlt(hlt)
  );

  assign stall = iDUT.PC_stall && iDUT.IF_ID_stall;

  // Test procedure to apply stimulus and check responses.
  initial begin
    // Initialize the testbench
    Initialize(.clk(clk), .rst_n(rst_n));

    // Run the simulation for each instruction in the instruction memory until HLT reaches WB.
    TimeoutTask(.sig(hlt), .clk(clk), .clks2wait(1000000), .signal("HLT"));

    // Wait for 3 cycles to print last actual instruction, HLT, and the instruction following it.
    repeat (3) @(posedge clk);
    
    $display("CPU halted due to HLT instruction.\n");

    // If we reached here, that means all test cases were successful.
    $display("YAHOO!! All tests passed.");
    $stop();
  end


  // Dump contents of BHT, BTB, Data memory, and Regfile contents.
  always @(negedge clk) begin
      if (rst_n) begin
        // Dump the contents of memory whenever we write to the BTB or BHT.
        if (iDUT.wen_BHT || iDUT.wen_BTB || hlt) begin
          log_BTB_BHT_dump (
            .model_BHT(iMODEL.iFETCH.iDBP_model.BHT),
            .model_BTB(iMODEL.iFETCH.iDBP_model.BTB),
            .dut_BHT(iDUT.iFETCH.iDBP.iBHT.iMEM_BHT.mem),
            .dut_BTB(iDUT.iFETCH.iDBP.iBTB.iMEM_BTB.mem)
          );
        end

        // Log data memory contents.
        if (iDUT.EX_MEM_MemEnable || hlt) begin
          log_data_dump(
              .model_data_mem(iMODEL.iDATA_MEM.data_memory),     
              .dut_data_mem(iDUT.iDATA_MEM.mem)          
          );
        end
        
        // Log the regfile contents.
        if (iDUT.MEM_WB_RegWrite || hlt) begin
          log_regfile_dump(.regfile(iMODEL.iDECODE.iRF.regfile));
        end
      end
  end


  // Pass the flush signal to the verify decode task.
  always @(posedge clk) begin
    if (!rst_n) begin
      IF_flush <= 1'b0;
      expected_IF_flush <= 1'b0;
    end else begin
      IF_flush <= iDUT.IF_flush;
      expected_IF_flush <= iMODEL.IF_flush;
    end
  end


  // Pass the hazard signals to the verify execute task.
  always @(posedge clk) begin
    if (!rst_n) begin
      load_to_use_hazard <= 1'b0;
      B_hazard <= 1'b0;
      BR_hazard <= 1'b0;
    end else begin
      load_to_use_hazard <= iDUT.iHDU.load_to_use_hazard;
      B_hazard <= iDUT.iHDU.B_hazard;
      BR_hazard <= iDUT.iHDU.BR_hazard;
    end
  end


  // Pass the ID flush signal to the verify execute task.
  always @(posedge clk) begin
    if (!rst_n) begin
      ID_flush <= 1'b0;
      expected_ID_flush <= 1'b0;
    end else begin
      ID_flush <= iDUT.ID_flush;
      expected_ID_flush <= iMODEL.ID_flush;
    end
  end


  always @(posedge clk) begin
    if (rst_n)
      $display("Z_flag_enable: %0d, V_flag_enable: %0d, N_flag_enable: %0d. Cycle: %0d.", iDUT.iEXECUTE.Z_en, iDUT.iEXECUTE.NV_en, iDUT.iEXECUTE.NV_en, ($time/10));
  end


  // Always block for verify_FETCH stage.
  always @(posedge clk) begin
      if (rst_n) begin
        // Local variable.
        string ftch_msg;

        // Verify FETCH stage logic.
        verify_FETCH(
              .PC_stall(iDUT.PC_stall),
              .expected_PC_stall(iMODEL.PC_stall),
              .HLT(iDUT.iDECODE.HLT),
              .PC_next(iDUT.PC_next), 
              .expected_PC_next(iMODEL.PC_next), 
              .PC_inst(iDUT.PC_inst), 
              .expected_PC_inst(iMODEL.PC_inst), 
              .PC_curr(pc), 
              .expected_PC_curr(expected_pc), 
              .prediction(iDUT.prediction), 
              .expected_prediction(iMODEL.prediction), 
              .predicted_target(iDUT.predicted_target), 
              .expected_predicted_target(iMODEL.predicted_target),
              .fetch_msg(ftch_msg)
        );

        fetch_msg = {"|", ftch_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};
    end
  end


  // Always block for verify_DECODE stage
  always @(posedge clk) begin
      if (rst_n) begin
        // Local variable.
        string dcode_msg;

        // Call the verify_DECODE task and get the decode message and full instruction message.
        verify_DECODE(
            .IF_ID_stall(iDUT.IF_ID_stall),
            .expected_IF_ID_stall(iMODEL.IF_ID_stall),
            .IF_flush(IF_flush),
            .expected_IF_flush(expected_IF_flush),
            .br_hazard(iMODEL.iHDU.BR_hazard),
            .b_hazard(iMODEL.iHDU.B_hazard),
            .load_use_hazard(iMODEL.iHDU.load_to_use_hazard),
            .hlt(iMODEL.iHDU.HLT),
            .EX_signals(iDUT.EX_signals),
            .expected_EX_signals(iMODEL.EX_signals),
            .MEM_signals(iDUT.MEM_signals),
            .expected_MEM_signals(iMODEL.MEM_signals),
            .WB_signals(iDUT.WB_signals),
            .expected_WB_signals(iMODEL.WB_signals),
            .cc(iDUT.iDECODE.c_codes),
            .flag_reg({iDUT.ZF, iDUT.VF, iDUT.NF}),
            .is_branch(iDUT.Branch),
            .expected_is_branch(iMODEL.Branch),
            .is_BR(iDUT.BR),
            .expected_is_BR(iMODEL.BR),
            .branch_target(iDUT.branch_target),
            .expected_branch_target(iMODEL.branch_target),
            .actual_taken(iDUT.actual_taken),
            .expected_actual_taken(iMODEL.actual_taken),
            .wen_BTB(iDUT.wen_BTB),
            .expected_wen_BTB(iMODEL.wen_BTB),
            .wen_BHT(iDUT.wen_BHT),
            .expected_wen_BHT(iMODEL.wen_BHT),
            .update_PC(iDUT.update_PC),
            .expected_update_PC(iMODEL.update_PC),
            
            .decode_msg(dcode_msg),
            .instruction_full(instruction_full_msg)
          );

        decode_msg = {"|", dcode_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};

      end
  end


    // Always block for verify_EXECUTE stage.
    always @(posedge clk) begin
      if (rst_n) begin
        // Local variable.
        string ex_msg;

        verify_EXECUTE(
          .Input_A(iDUT.iEXECUTE.iALU.Input_A),
          .Input_B(iDUT.iEXECUTE.iALU.Input_B),
          .expected_Input_A(iMODEL.iEXECUTE.iALU_model.Input_A),
          .expected_Input_B(iMODEL.iEXECUTE.iALU_model.Input_B),
          .ALU_out(iDUT.ALU_out),
          .ID_flush(ID_flush),
          .expected_ID_flush(expected_ID_flush),
          .br_hazard(BR_hazard),
          .b_hazard(B_hazard),
          .load_use_hazard(load_to_use_hazard),
          .Z_set(iDUT.iEXECUTE.iALU.Z_set),
          .V_set(iDUT.iEXECUTE.iALU.V_set),
          .N_set(iDUT.iEXECUTE.iALU.N_set),
          .expected_ALU_out(iMODEL.ALU_out),
          .ZF(iDUT.ZF),
          .NF(iDUT.NF),
          .VF(iDUT.VF),
          .expected_ZF(iMODEL.ZF),
          .expected_VF(iMODEL.VF),
          .expected_NF(iMODEL.NF),
          
          .execute_msg(ex_msg)
        );

        execute_msg = {"|", ex_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};
      
    end   
  end


  // Always block for verify_MEMORY stage.
  always @(posedge clk) begin
    if (rst_n) begin
      // Local variable.
      string mem_verify_msg;

      verify_MEMORY(
        .EX_MEM_ALU_out(iDUT.EX_MEM_ALU_out),
        .MemData(iDUT.MemData),
        .expected_MemData(iMODEL.MemData),
        .MemWriteData(iDUT.MemWriteData),
        .expected_MemWriteData(iMODEL.MemWriteData),
        .EX_MEM_MemEnable(iDUT.EX_MEM_MemEnable),
        .EX_MEM_MemWrite(iDUT.EX_MEM_MemWrite),
        
        .mem_verify_msg(mem_verify_msg)
      );
      
      mem_msg = {"|", mem_verify_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};

    end
  end


  // Always block for verify_WRITEBACK stage.
  always @(posedge clk) begin
    if (rst_n) begin
      // Local variable.
      string wbb_msg;

      verify_WRITEBACK(
        .MEM_WB_DstReg(iDUT.MEM_WB_reg_rd),
        .MEM_WB_RegWrite(iDUT.MEM_WB_RegWrite),
        .RegWriteData(iDUT.RegWriteData),
        .expected_RegWriteData(iMODEL.RegWriteData),
        
        .wb_verify_msg(wbb_msg)
      );
      
      wb_msg = {"|", wbb_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};

    end
  end


  // Generate clock signal with 10 ns period
  always 
    #5 clk = ~clk;

endmodule