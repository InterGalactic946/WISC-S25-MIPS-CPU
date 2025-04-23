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
  logic stall;                       // Indicates a stall in the pipeline.
  
  logic wen_BHT;                     // Write enable for BHT
  logic wen_BTB;                     // Write enable for BTB
  logic MemEnable;                   // Enable for memory
  logic RegWrite;                    // Register write signal
  logic HLT;                         // hlt instruction

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

  assign stall = iDUT.iPROC.PC_stall && iDUT.iPROC.IF_ID_stall;

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


  // Dump contents of BHT, BTB, Data memory, and Regfile contents.
  always @(negedge clk) begin
      if (rst_n) begin
        // Dump the contents of memory whenever we write to the BTB or BHT.
        if (wen_BHT || wen_BTB || HLT) begin
          log_BTB_BHT_dump (
            .model_BHT(iMODEL.iPROC.iFETCH.iDBP_model.BHT),
            .model_BTB(iMODEL.iPROC.iFETCH.iDBP_model.BTB)
          );
        end

        // // Log data memory contents.
        // if (MemEnable || HLT) begin
        //   log_data_dump(
        //       .model_data_mem(iMODEL.iPROC.iDATA_MEM.data_memory),     
        //       .dut_data_mem(iDUT.iPROC.iDATA_MEM.mem)          
        //   );
        // end
        
        // Log the regfile contents.
        if (RegWrite || HLT) begin
          log_regfile_dump(.regfile(iMODEL.iPROC.iDECODE.iRF.regfile));
        end
      end
  end

  // Pipeline the write/enable signals for printing out.
  always @(posedge clk) begin
    if (!rst_n) begin
      wen_BHT <= 1'b0;
      wen_BTB <= 1'b0;
      MemEnable <= 1'b0;
      RegWrite <= 1'b0;
      HLT <= 1'b0;
    end else begin
      wen_BHT <= iDUT.iPROC.wen_BHT;
      wen_BTB <= iDUT.iPROC.wen_BTB;
      MemEnable <= iDUT.iPROC.EX_MEM_MemEnable;
      RegWrite <= iDUT.iPROC.MEM_WB_RegWrite;
      HLT <= hlt;
    end
  end

  // Pass the flush signal to the verify decode task.
  always @(posedge clk) begin
    if (!rst_n) begin
      IF_flush <= 1'b0;
      expected_IF_flush <= 1'b0;
    end else begin
      IF_flush <= iDUT.iPROC.IF_flush;
      expected_IF_flush <= iMODEL.iPROC.IF_flush;
    end
  end


  // Pass the hazard signals to the verify execute task.
  always @(posedge clk) begin
    if (!rst_n) begin
      load_to_use_hazard <= 1'b0;
      B_hazard <= 1'b0;
      BR_hazard <= 1'b0;
    end else begin
      load_to_use_hazard <= iDUT.iPROC.iHDU.load_to_use_hazard;
      B_hazard <= iDUT.iPROC.iHDU.B_hazard;
      BR_hazard <= iDUT.iPROC.iHDU.BR_hazard;
    end
  end


  // Pass the ID flush signal to the verify execute task.
  always @(posedge clk) begin
    if (!rst_n) begin
      ID_flush <= 1'b0;
      expected_ID_flush <= 1'b0;
    end else begin
      ID_flush <= iDUT.iPROC.ID_flush;
      expected_ID_flush <= iMODEL.iPROC.ID_flush;
    end
  end


  // Always block for verify_FETCH stage.
  always @(posedge clk) begin
      if (rst_n) begin
        // Local variable.
        string ftch_msg;

        // Verify FETCH stage logic.
        verify_FETCH(
              .PC_stall(iDUT.iPROC.PC_stall),
              .expected_PC_stall(iMODEL.iPROC.PC_stall),
              .HLT(iDUT.iPROC.iDECODE.HLT),
              .PC_next(iDUT.iPROC.PC_next), 
              .expected_PC_next(iMODEL.iPROC.PC_next), 
              .PC_inst(iDUT.iPROC.PC_inst), 
              .expected_PC_inst(iMODEL.iPROC.PC_inst), 
              .PC_curr(pc), 
              .expected_PC_curr(expected_pc), 
              .prediction(iDUT.iPROC.prediction), 
              .expected_prediction(iMODEL.iPROC.prediction),
              .predicted_taken(iDUT.iPROC.iFETCH.predicted_taken),
              .expected_predicted_taken(iMODEL.iPROC.iFETCH.predicted_taken), 
              .predicted_target(iDUT.iPROC.predicted_target), 
              .expected_predicted_target(iMODEL.iPROC.predicted_target),
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
            .IF_ID_stall(iDUT.iPROC.IF_ID_stall),
            .expected_IF_ID_stall(iMODEL.iPROC.IF_ID_stall),
            .IF_flush(IF_flush),
            .expected_IF_flush(expected_IF_flush),
            .br_hazard(iMODEL.iPROC.iHDU.BR_hazard),
            .b_hazard(iMODEL.iPROC.iHDU.B_hazard),
            .load_use_hazard(iMODEL.iPROC.iHDU.load_to_use_hazard),
            .EX_signals(iDUT.iPROC.EX_signals),
            .expected_EX_signals(iMODEL.iPROC.EX_signals),
            .MEM_signals(iDUT.iPROC.MEM_signals),
            .expected_MEM_signals(iMODEL.iPROC.MEM_signals),
            .WB_signals(iDUT.iPROC.WB_signals),
            .expected_WB_signals(iMODEL.iPROC.WB_signals),
            .cc(iDUT.iPROC.iDECODE.c_codes),
            .flag_reg({iDUT.iPROC.ZF, iDUT.iPROC.VF, iDUT.iPROC.NF}),
            .is_branch(iDUT.iPROC.Branch),
            .expected_is_branch(iMODEL.iPROC.Branch),
            .is_BR(iDUT.iPROC.BR),
            .expected_is_BR(iMODEL.iPROC.BR),
            .actual_target(iDUT.iPROC.actual_target),
            .expected_actual_target(iMODEL.iPROC.actual_target),
            .actual_taken(iDUT.iPROC.actual_taken),
            .expected_actual_taken(iMODEL.iPROC.actual_taken),
            .wen_BTB(iDUT.iPROC.wen_BTB),
            .expected_wen_BTB(iMODEL.iPROC.wen_BTB),
            .wen_BHT(iDUT.iPROC.wen_BHT),
            .expected_wen_BHT(iMODEL.iPROC.wen_BHT),
            .update_PC(iDUT.iPROC.update_PC),
            .expected_update_PC(iMODEL.iPROC.update_PC),
            
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
          .Input_A(iDUT.iPROC.iEXECUTE.iALU.Input_A),
          .Input_B(iDUT.iPROC.iEXECUTE.iALU.Input_B),
          .expected_Input_A(iMODEL.iPROC.iEXECUTE.iALU_model.Input_A),
          .expected_Input_B(iMODEL.iPROC.iEXECUTE.iALU_model.Input_B),
          .ALU_out(iDUT.iPROC.ALU_out),
          .ID_flush(ID_flush),
          .expected_ID_flush(expected_ID_flush),
          .br_hazard(BR_hazard),
          .b_hazard(B_hazard),
          .load_use_hazard(load_to_use_hazard),
          .Z_set(iDUT.iPROC.iEXECUTE.iALU.Z_set),
          .V_set(iDUT.iPROC.iEXECUTE.iALU.V_set),
          .N_set(iDUT.iPROC.iEXECUTE.iALU.N_set),
          .expected_ALU_out(iMODEL.iPROC.ALU_out),
          .ZF(iDUT.iPROC.ZF),
          .NF(iDUT.iPROC.NF),
          .VF(iDUT.iPROC.VF),
          .expected_ZF(iMODEL.iPROC.ZF),
          .expected_VF(iMODEL.iPROC.VF),
          .expected_NF(iMODEL.iPROC.NF),
          
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
        .EX_MEM_ALU_out(iDUT.iPROC.EX_MEM_ALU_out),
        .MemData(iDUT.iPROC.MemData),
        .expected_MemData(iMODEL.iPROC.MemData),
        .MemWriteData(iDUT.iPROC.MemWriteData),
        .expected_MemWriteData(iMODEL.iPROC.MemWriteData),
        .EX_MEM_MemEnable(iDUT.iPROC.EX_MEM_MemEnable),
        .EX_MEM_MemWrite(iDUT.iPROC.EX_MEM_MemWrite),
        
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
        .MEM_WB_DstReg(iDUT.iPROC.MEM_WB_reg_rd),
        .MEM_WB_RegWrite(iDUT.iPROC.MEM_WB_RegWrite),
        .RegWriteData(iDUT.iPROC.RegWriteData),
        .expected_RegWriteData(iMODEL.iPROC.RegWriteData),
        
        .wb_verify_msg(wbb_msg)
      );
      
      wb_msg = {"|", wbb_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};

    end
  end


  // Generate clock signal with 10 ns period
  always 
    #5 clk = ~clk;

endmodule