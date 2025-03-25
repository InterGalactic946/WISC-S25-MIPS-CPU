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

  // Importing task libraries
  import Display_tasks::*;
  import Monitor_tasks::*;
  import Verification_tasks::*;

  ///////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  logic clk, rst_n;           // Clock and reset signals
  logic hlt, expected_hlt;    // Halt signals for execution stop for each DUT and model
  logic [15:0] expected_pc;   // Expected program counter value for verification
  logic [15:0] pc;            // Current program counter value
  logic stall, flush;         // Indicates a stall and/or a flush in the pipeline.

  // Messages from each stage.
  string fetch_msg, if_id_msg, decode_msg, instruction_full_msg, id_ex_msg, 
         execute_msg, ex_mem_msg, mem_msg, mem_wb_msg, wb_msg, pc_stall_msg, if_id_stall_msg, if_flush_msg, id_flush_msg, instruction_header;

  reg [255:0] fetch_stage_msg, decode_stage_msg, full_instruction_msg;

  
  // Store the messages for FETCH and DECODE stages
reg [31:0] instruction_cycle; // Store the cycle when the instruction is completed

logic valid_fetch, valid_decode;



  
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
  //  Verification_Unit iVERIFY (
  //   .clk(clk),
  //   .rst(rst),
  //   .if_id_msg(if_id_msg),
  //   .decode_msg(decode_msg),
  //   .instruction_full_msg(instruction_full_msg),
  //   .id_ex_msg(id_ex_msg),
  //   .execute_msg(execute_msg),
  //   .ex_mem_msg(ex_mem_msg),
  //   .mem_msg(mem_msg),
  //   .mem_wb_msg(mem_wb_msg),
  //   .wb_msg(wb_msg),
  //   .pc_stall_msg(pc_stall_msg),
  //   .if_id_stall_msg(if_id_stall_msg),
  //   .if_flush_msg(if_flush_msg),
  //   .id_flush_msg(id_flush_msg),
  //   .stall(stall),
  //   .flush(flush)
  // );

  // Test procedure to apply stimulus and check responses.
  initial begin
    // Initialize the testbench
    Initialize(.clk(clk), .rst_n(rst_n));

    // Run the simulation for each instruction in the instruction memory until HLT reaches WB.
    TimeoutTask(.sig(hlt), .clk(clk), .clks2wait(1000000), .signal("HLT"));

    // If we reached here, that means all test cases were successful
    $display("YAHOO!! All tests passed.");
    $stop();
  end

  // We stall on PC or IF.
  assign stall = iDUT.PC_stall || iDUT.IF_ID_stall;

  // We flush IF, or ID stage.
  assign flush = iDUT.IF_flush || iDUT.ID_flush;

  // // Get the hazard messages.
  // always @(posedge clk) begin
  //     if (rst_n) begin
  //       get_hazard_messages(
  //           .pc_stall(iMODEL.PC_stall), 
  //           .if_id_stall(iMODEL.IF_ID_stall),
  //           .if_flush(iMODEL.IF_flush),
  //           .id_flush(iMODEL.ID_flush),
  //           .br_hazard(iMODEL.iHDU.BR_hazard),
  //           .b_hazard(iMODEL.iHDU.B_hazard),
  //           .load_use_hazard(iMODEL.iHDU.load_to_use_hazard),
  //           .hlt(expected_hlt),
  //           .pc_stall_msg(pc_stall_msg),
  //           .if_id_stall_msg(if_id_stall_msg),
  //           .if_flush_msg(if_flush_msg),
  //           .id_flush_msg(id_flush_msg)
  //       );

  //         // $display(pc_message);
  //         // $display(if_id_hz_message);
  //         // $display(id_ex_hz_message);
  //         // $display(flush_message);
  //     end
  // end


  // Dump contents of BHT, BTB, Data memory, and Regfile contents.
  always @(negedge clk) begin
      if (rst_n) begin
        // Dump the contents of memory whenever we write to the BTB or BHT.
        if (iDUT.wen_BHT || iDUT.wen_BTB) begin
          log_BTB_BHT_dump (
            .model_BHT(iMODEL.iFETCH.iDBP_model.BHT),
            .model_BTB(iMODEL.iFETCH.iDBP_model.BTB),
            .dut_BHT(iDUT.iFETCH.iDBP.iBHT.iMEM_BHT.mem),
            .dut_BTB(iDUT.iFETCH.iDBP.iBTB.iMEM_BTB.mem)
          );
        end

        // Log data memory contents.
        if (iDUT.EX_MEM_MemEnable) begin
          log_data_dump(
              .model_data_mem(iMODEL.iDATA_MEM.data_memory),     
              .dut_data_mem(iDUT.iDATA_MEM.mem)          
          );
        end
        
        // Log the regfile contents.
        if (iDUT.MEM_WB_RegWrite) begin
          log_regfile_dump(.regfile(iMODEL.iDECODE.iRF.regfile));
        end
      end
  end

  // // Always block for verify_FETCH stage
  // always @(posedge clk) begin
  //   if (rst_n) begin
  //   verify_FETCH(
  //         .PC_stall(iDUT.PC_stall),
  //         .expected_PC_stall(iMODEL.PC_stall),
  //         .HLT(iDUT.iDECODE.HLT),
  //         .PC_next(iDUT.PC_next), 
  //         .expected_PC_next(iMODEL.PC_next), 
  //         .PC_inst(iDUT.PC_inst), 
  //         .expected_PC_inst(iMODEL.PC_inst), 
  //         .PC_curr(pc), 
  //         .expected_PC_curr(expected_pc), 
  //         .prediction(iDUT.prediction), 
  //         .expected_prediction(iMODEL.prediction), 
  //         .predicted_target(iDUT.predicted_target), 
  //         .expected_predicted_target (iMODEL.predicted_target),
  //         .stage("FETCH"),
  //         .stage_msg(fetch_msg)
  //     );

  //     $display("|%s @ Cycle: %0t", fetch_msg, $time/10);
  //   end
  // end


  // // // Always block for verify_IF_ID stage
  // // always @(negedge clk) begin
  // //   if (rst_n) begin
  // //     verify_IF_ID(
  // //       .IF_ID_signals({iDUT.IF_ID_PC_curr, iDUT.IF_ID_PC_next, iDUT.IF_ID_PC_inst, 
  // //                       iDUT.IF_ID_prediction, iDUT.IF_ID_predicted_target}),
  // //       .expected_IF_ID_signals({iMODEL.IF_ID_PC_curr, iMODEL.IF_ID_PC_next, iMODEL.IF_ID_PC_inst, 
  // //                               iMODEL.IF_ID_prediction, iMODEL.IF_ID_predicted_target}),
  // //       .PC_stall(iMODEL.PC_stall),
  // //       .IF_ID_stall(iMODEL.IF_ID_stall),
  // //       .IF_flush(iMODEL.IF_flush),
  // //       .br_hazard(iMODEL.iHDU.BR_hazard),
  // //       .b_hazard(iMODEL.iHDU.B_hazard),
  // //       .load_use_hazard(iMODEL.iHDU.load_to_use_hazard),
  // //       .hlt(expected_hlt),
        
  // //       .if_id_msg(if_id_msg)
  // //     );

  // //     // $display(if_id_msg);
  // //   end
  // // end

  // // Always block for verify_DECODE stage
  // always @(posedge clk) begin
  //   if (rst_n) begin
  //     verify_DECODE(
  //       .IF_ID_stall(iDUT.IF_ID_stall),
  //       .expected_IF_ID_stall(iMODEL.IF_ID_stall),
  //       .IF_flush(iDUT.IF_flush),
  //       .expected_IF_flush(iMODEL.IF_flush),
  //       .br_hazard(iMODEL.iHDU.BR_hazard),
  //       .b_hazard(iMODEL.iHDU.B_hazard),
  //       .load_use_hazard(iMODEL.iHDU.load_to_use_hazard),
  //       .EX_signals(iDUT.EX_signals),
  //       .expected_EX_signals(iMODEL.EX_signals),
  //       .MEM_signals(iDUT.MEM_signals),
  //       .expected_MEM_signals(iMODEL.MEM_signals),
  //       .WB_signals(iDUT.WB_signals),
  //       .expected_WB_signals(iMODEL.WB_signals),
  //       .cc(iDUT.iDECODE.c_codes),
  //       .flag_reg({iDUT.ZF, iDUT.VF, iDUT.NF}),
  //       .is_branch(iDUT.Branch),
  //       .expected_is_branch(iMODEL.Branch),
  //       .is_BR(iDUT.BR),
  //       .expected_is_BR(iMODEL.BR),
  //       .branch_target(iDUT.branch_target),
  //       .expected_branch_target(iMODEL.branch_target),
  //       .actual_taken(iDUT.actual_taken),
  //       .expected_actual_taken(iMODEL.actual_taken),
  //       .wen_BTB(iDUT.wen_BTB),
  //       .expected_wen_BTB(iMODEL.wen_BTB),
  //       .wen_BHT(iDUT.wen_BHT),
  //       .expected_wen_BHT(iMODEL.wen_BHT),
  //       .update_PC(iDUT.update_PC),
  //       .expected_update_PC(iMODEL.update_PC),
        
  //       .decode_msg(decode_msg),
  //       .instruction_full(instruction_full_msg)
  //     );

  //     //$display(instruction_full_msg);
  //     $display("|%s @ Cycle: %0t", decode_msg, $time/10);

  //   end
  // end

// Queues to store FETCH and DECODE messages
string fetch_queue[$];    // Queue for FETCH messages
string decode_queue[$];   // Queue for DECODE messages
string instruction_queue[$]; // Queue for full instruction header
int cycle_queue[$];        // Queue to track cycle number for WB

// Always block for verify_FETCH stage
always @(posedge clk) begin
    if (rst_n) begin
        // Call the verify_FETCH task and get the fetch message
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
            .stage("FETCH"),
            .stage_msg(fetch_msg)
        );

        // Append the FETCH message to the queue with the cycle info
        fetch_queue.push_back({fetch_msg, " @ Cycle: ", $sformatf("%0d", $time/10)});
    end
end

always @(posedge clk) begin
    if (rst_n) begin
        if (stall) begin
            valid_fetch <= 1'b0;
        end else begin
            valid_fetch <= 1'b1;
        end

        valid_decode <= valid_fetch; // Decode is only valid if fetch was valid in the previous cycle
    end else begin
        valid_fetch <= 1'b0;
        valid_decode <= 1'b0;
    end
end

// Always block for verify_DECODE stage
always @(posedge clk) begin
    if (rst_n) begin
        // Call the verify_DECODE task and get the decode message
        verify_DECODE(
            .IF_ID_stall(iDUT.IF_ID_stall),
            .expected_IF_ID_stall(iMODEL.IF_ID_stall),
            .IF_flush(iDUT.IF_flush),
            .expected_IF_flush(iMODEL.IF_flush),
            .br_hazard(iMODEL.iHDU.BR_hazard),
            .b_hazard(iMODEL.iHDU.B_hazard),
            .load_use_hazard(iMODEL.iHDU.load_to_use_hazard),
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
            .decode_msg(decode_msg),
            .instruction_full(instruction_full_msg)
        );

        if (valid_decode) begin
            // Correct DECODE cycle tracking (Fetch happens one cycle earlier)
            decode_queue.push_back({decode_msg, " @ Cycle: ", $sformatf("%0d", ($time/10) - 1)});
            instruction_queue.push_back(instruction_full_msg);
        end
    end
end

// Print when both FETCH and DECODE are available
always @(posedge clk) begin
    if (rst_n) begin
        // Ensure both queues have entries before printing
        if (fetch_queue.size() > 0 && decode_queue.size() > 0 && valid_decode) begin
            string fetch_msg_out, decode_msg_out, instr_out;
            int completed_cycle;

            // Pop from both queues in FIFO order
            fetch_msg_out = fetch_queue.pop_front();
            decode_msg_out = decode_queue.pop_front();
            instr_out = instruction_queue.pop_front();
            completed_cycle = $time/10;

            // Print formatted instruction execution summary
            $display("========================================================");
            $display("| Instruction: %s | Completed At Cycle: %0d |", instr_out, completed_cycle);
            $display("========================================================");
            $display("|%s", fetch_msg_out);
            $display("|%s", decode_msg_out);
            $display("========================================================");
        end
    end
end



  // // always @(posedge clk)
  // //   $display("Src_data1: %04x, Expected_Src_Data1: %04x", iDUT.iDECODE.SrcReg1_data, iMODEL.iDECODE.SrcReg1_data);

  // // Always block for verify_ID_EX stage
  // always @(negedge clk) begin
  //   if (rst_n) begin
  //     verify_ID_EX(
  //       .ID_EX_signals({iDUT.ID_EX_PC_next, iDUT.ID_EX_SrcReg1, iDUT.ID_EX_SrcReg2, 
  //                       iDUT.ID_EX_ALU_In1, iDUT.ID_EX_ALU_imm, iDUT.ID_EX_ALU_In2, 
  //                       iDUT.ID_EX_ALUOp, iDUT.ID_EX_ALUSrc, iDUT.ID_EX_Z_en, 
  //                       iDUT.ID_EX_NV_en, iDUT.ID_EX_MEM_signals, iDUT.ID_EX_WB_signals}),
  //       .expected_ID_EX_signals({iMODEL.ID_EX_PC_next, iMODEL.ID_EX_SrcReg1, iMODEL.ID_EX_SrcReg2, 
  //                               iMODEL.ID_EX_ALU_In1, iMODEL.ID_EX_ALU_imm, iMODEL.ID_EX_ALU_In2, 
  //                               iMODEL.ID_EX_ALUOp, iMODEL.ID_EX_ALUSrc, iMODEL.ID_EX_Z_en, 
  //                               iMODEL.ID_EX_NV_en, iMODEL.ID_EX_MEM_signals, iMODEL.ID_EX_WB_signals}),
        
  //       .id_ex_message(id_ex_msg)
  //     );

  //     // $display(id_ex_message);
  //   end
  // end

  // // Always block for verify_EXECUTE stage
  // always @(negedge clk) begin
  //   if (rst_n) begin
  //     verify_EXECUTE(
  //       .Input_A(iDUT.iEXECUTE.iALU.Input_A),
  //       .Input_B(iDUT.iEXECUTE.iALU.Input_B),
  //       .expected_Input_A(iMODEL.iEXECUTE.iALU_model.Input_A),
  //       .expected_Input_B(iMODEL.iEXECUTE.iALU_model.Input_B),
  //       .ALU_out(iDUT.ALU_out),
  //       .Z_set(iDUT.iEXECUTE.iALU.Z_set),
  //       .V_set(iDUT.iEXECUTE.iALU.V_set),
  //       .N_set(iDUT.iEXECUTE.iALU.N_set),
  //       .expected_ALU_out(iMODEL.ALU_out),
  //       .ZF(iDUT.ZF),
  //       .NF(iDUT.NF),
  //       .VF(iDUT.VF),
  //       .expected_ZF(iMODEL.ZF),
  //       .expected_VF(iMODEL.VF),
  //       .expected_NF(iMODEL.NF),
        
  //       .execute_msg(execute_msg)
  //     );

  //     // $display(execute_msg);
  //   end
  // end

  // // Always block for verify_EX_MEM stage.
  // always @(negedge clk) begin
  //   if (rst_n) begin
  //       verify_EX_MEM(
  //         .EX_MEM_signals({iDUT.EX_MEM_PC_next, iDUT.EX_MEM_ALU_out, iDUT.EX_MEM_SrcReg2, 
  //                         iDUT.EX_MEM_MemWriteData, iDUT.EX_MEM_MemEnable, iDUT.EX_MEM_MemWrite, 
  //                         iDUT.EX_MEM_WB_signals}),
  //         .expected_EX_MEM_signals({iMODEL.EX_MEM_PC_next, iMODEL.EX_MEM_ALU_out, iMODEL.EX_MEM_SrcReg2, 
  //                                   iMODEL.EX_MEM_MemWriteData, iMODEL.EX_MEM_MemEnable, 
  //                                   iMODEL.EX_MEM_MemWrite, iMODEL.EX_MEM_WB_signals}),
          
  //         .ex_mem_message(ex_mem_msg)
  //       );

  //       // $display(ex_mem_message);
  //   end
  // end

  // // Always block for verify_MEMORY stage
  // always @(negedge clk) begin
  //   if (rst_n) begin
  //     verify_MEMORY(
  //       .EX_MEM_ALU_out(iDUT.EX_MEM_ALU_out),
  //       .MemData(iDUT.MemData),
  //       .expected_MemData(iMODEL.MemData),
  //       .MemWriteData(iDUT.MemWriteData),
  //       .expected_MemWriteData(iMODEL.MemWriteData),
  //       .EX_MEM_MemEnable(iDUT.EX_MEM_MemEnable),
  //       .EX_MEM_MemWrite(iDUT.EX_MEM_MemWrite),
        
  //       .mem_verify_msg(mem_msg)
  //     );

  //     // $display(mem_verify_msg);
  //   end
  // end

  // // Always block for verify_MEM_WB stage
  // always @(negedge clk) begin
  //   if (rst_n) begin
  //     verify_MEM_WB(
  //       .MEM_WB_signals({iDUT.MEM_WB_PC_next, iDUT.MEM_WB_ALU_out, iDUT.MEM_WB_MemData, 
  //                       iDUT.MEM_WB_reg_rd, iDUT.MEM_WB_RegWrite, iDUT.MEM_WB_MemToReg, 
  //                       iDUT.MEM_WB_HLT, iDUT.MEM_WB_PCS}),
  //       .expected_MEM_WB_signals({iMODEL.MEM_WB_PC_next, iMODEL.MEM_WB_ALU_out, iMODEL.MEM_WB_MemData, 
  //                                 iMODEL.MEM_WB_reg_rd, iMODEL.MEM_WB_RegWrite, iMODEL.MEM_WB_MemToReg, 
  //                                 iMODEL.MEM_WB_HLT, iMODEL.MEM_WB_PCS}),
        
  //       .mem_wb_message(mem_wb_msg)
  //     );

  //     // $display(mem_wb_message);
  //   end
  // end

  // // Always block for verify_WRITEBACK stage
  // always @(negedge clk) begin
  //   if (rst_n) begin
  //     verify_WRITEBACK(
  //       .MEM_WB_DstReg(iDUT.MEM_WB_reg_rd),
  //       .MEM_WB_RegWrite(iDUT.MEM_WB_RegWrite),
  //       .RegWriteData(iDUT.RegWriteData),
  //       .expected_RegWriteData(iMODEL.RegWriteData),
        
  //       .wb_verify_msg(wb_msg)
  //     );


  //     // $display(wb_verify_msg);
  //   end
  // end

  // Generate clock signal with 10 ns period
  always 
    #5 clk = ~clk;

endmodule