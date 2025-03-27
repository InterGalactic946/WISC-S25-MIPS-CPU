///////////////////////////////////////////////////////////
// Verification_tasks.sv: Tasks for comparing DUT with    //
// the CPU model.                                         //
// This package contains tasks to compare the behavior    //
// of the Design Under Test (DUT) with the reference model //
// to ensure that the DUT operates correctly and matches  //
// the model's expected behavior. Tasks include checking  //
// instruction execution, memory operations, register     //
// updates, and control logic for consistency.            //
///////////////////////////////////////////////////////////
package Verification_tasks;

  import Display_tasks::*;

  // Task to initialize testbench signals.
  task automatic Initialize(ref logic clk, ref logic rst_n);
    begin
      clk = 1'b0;
      @(posedge clk);
      @(negedge clk) rst_n = 1'b0;
      repeat (2) @(posedge clk);   // Wait for 2 clock cycles
      @(negedge clk) rst_n = 1'b1; // Deassert reset
    end
  endtask


  // Task to wait for a signal to be asserted, otherwise times out.
  task automatic TimeoutTask(ref sig, ref clk, input int clks2wait, input string signal);
    fork
      begin : timeout
        repeat(clks2wait) @(posedge clk);
        $display("ERROR: %s not getting asserted and/or held at its value.", signal);
        $stop(); // Stop simulation on error.
      end : timeout
      begin
        @(posedge sig) disable timeout; // Disable timeout if sig is asserted.
        $display("CPU halted due to HLT instruction.");
      end
    join
  endtask


  // Task: A task to verify the FETCH stage.
  task automatic verify_FETCH(
      input logic PC_stall, expected_PC_stall, HLT,
      input logic [15:0] PC_next, expected_PC_next,
      input logic [15:0] PC_inst, expected_PC_inst,
      input logic [15:0] PC_curr, expected_PC_curr,
      input logic [1:0]  prediction, expected_prediction,
      input logic [15:0] predicted_target, expected_predicted_target,
      input string stage,
      output string stage_msg, stall_msg 
  );
    begin
        // Initialize message.
        stage_msg = "";
        stall_msg = "";

          // Verify the PC next.
          if (PC_next !== expected_PC_next) begin
              stage_msg = $sformatf("[%s] ERROR: PC_next: 0x%h, expected_PC_next: 0x%h.", stage, PC_next, expected_PC_next);
              return;  // Exit task on error
          end

          // Verify the PC instruction.
          if (PC_inst !== expected_PC_inst) begin
              stage_msg = $sformatf("[%s] ERROR: PC_inst: 0x%h, expected_PC_inst: 0x%h.", stage, PC_inst, expected_PC_inst);
              return;  // Exit task on error
          end

          // Verify the PC.
          if (PC_curr !== expected_PC_curr) begin
              stage_msg = $sformatf("[%s] ERROR: PC_curr: 0x%h, expected_PC_curr: 0x%h.", stage, PC_curr, expected_PC_curr);
              return;  // Exit task on error
          end

          // Verify the prediction.
          if (prediction !== expected_prediction) begin
              stage_msg = $sformatf("[%s] ERROR: predicted_taken: %b, expected_predicted_taken: %b.", stage, prediction[1], expected_prediction[1]);
              return;  // Exit task on error
          end

          // Verify the predicted target.
          if (predicted_target !== expected_predicted_target) begin
              stage_msg = $sformatf("[%s] ERROR: predicted_target: 0x%h, expected_pred_target: 0x%h.", stage, predicted_target, expected_predicted_target);
              return;  // Exit task on error
          end

          // Verify the stall state.
          if (PC_stall !== expected_PC_stall) begin
              stage_msg = $sformatf("[%s] ERROR: PC_stall: %b, expected_PC_stall: %b.", stage, PC_stall, expected_PC_stall);
              return;  // Exit task on error
          end

          if (prediction[1])
              // Branch is predicted taken.
              stage_msg = $sformatf("[%s] SUCCESS: PC_curr: 0x%h, PC_next: 0x%h, Instruction: 0x%h | Branch Predicted Taken | Predicted Target: 0x%h.",
                                                stage, PC_curr, PC_next, PC_inst, predicted_target);
           else if (!prediction[1])
              // Branch is not predicted taken.
              stage_msg = $sformatf("[%s] SUCCESS: PC_curr: 0x%h, PC_next: 0x%h, Instruction: 0x%h | Branch Predicted NOT Taken.",
                                                stage, PC_curr, PC_next, PC_inst);
          
          // If all checks pass, store success message.
          if (PC_stall && !HLT) // If the stall is not due to HLT.
            stall_msg = $sformatf("[%s] STALL: PC stalled due to propagated stall. PC_curr: 0x%h, PC_next: 0x%h, Instruction: 0x%h.", stage,  PC_curr, PC_next, PC_inst);
          else if (PC_stall && HLT)
            stall_msg = $sformatf("[%s] STALL: PC stalled due to HLT instruction. PC_curr: 0x%h, PC_next: 0x%h, Instruction: 0x%h.", stage,  PC_curr, PC_next, PC_inst);
    end
  endtask


  // Task: Verifies IF/ID Pipeline Register.
  task automatic verify_IF_ID(
      input logic [65:0] IF_ID_signals, input logic [65:0] expected_IF_ID_signals, 
      input logic PC_stall, IF_ID_stall, IF_flush,
      input logic br_hazard, b_hazard, load_use_hazard, hlt,
      output string if_id_msg
  );
    begin
    string hazard_type = "";

    // Determine the type of hazard and generate the appropriate message.
    if (load_use_hazard) begin
        hazard_type = "load-to-use hazard";
    end else if (br_hazard) begin
        hazard_type = "Branch (BR) hazard";
    end else if (b_hazard) begin
        hazard_type = "Branch (B) hazard";
    end else if (hlt) begin
        hazard_type = "HLT instruction";
    end

    // Handle PC/IF_ID_stall messages.
    if (PC_stall && IF_ID_stall) begin
        if_id_msg = $sformatf("[FETCH]: PC stalled due to %s.\n|[IF_ID]: IF_ID stalled due to %s.", hazard_type, hazard_type);
        return;
    // end else if (IF_flush) begin
    //     if_id_msg = $sformatf("[FLUSH]: IF flushed due to mispredicted branch.");
    //     return;
    end else begin

        // // Verify fetch otheriwse.
        // verify_FETCH(
        //     .PC_next(IF_ID_signals[49:34]), 
        //     .expected_PC_next(expected_IF_ID_signals[49:34]), 
        //     .PC_inst(IF_ID_signals[33:18]), 
        //     .expected_PC_inst(expected_IF_ID_signals[33:18]), 
        //     .PC_curr(IF_ID_signals[65:50]), 
        //     .expected_PC_curr(expected_IF_ID_signals[65:50]), 
        //     .prediction(IF_ID_signals[17:16]), 
        //     .expected_prediction(expected_IF_ID_signals[17:16]), 
        //     .predicted_target(IF_ID_signals[15:0]), 
        //     .expected_predicted_target (expected_IF_ID_signals[15:0]),
        //     .stage("IF_ID"),
        //     .stage_msg(if_id_msg)
        // );
    end
    end
  endtask


  // Task: Verify the DECODE stage.
  task automatic verify_DECODE(
      input logic IF_ID_stall, expected_IF_ID_stall,
      input logic IF_flush, expected_IF_flush,
      input logic br_hazard, b_hazard, load_use_hazard, hlt,
      input logic [62:0] EX_signals, expected_EX_signals,
      input logic [17:0] MEM_signals, expected_MEM_signals,
      input logic [7:0] WB_signals, expected_WB_signals,
      input logic [2:0] cc, flag_reg,
      input logic is_branch, expected_is_branch,
      input logic is_BR, expected_is_BR,
      input logic [15:0] branch_target, expected_branch_target,
      input logic actual_taken, expected_actual_taken,
      input logic wen_BTB, expected_wen_BTB,
      input logic wen_BHT, expected_wen_BHT,
      input logic update_PC, expected_update_PC,
      output string decode_msg, stall_msg,
      output string instruction_full, instr_flush_msg
  );
      begin
          // Stores the state of the decoded instruction.
          string instr_state;
          string hazard_type;

          // Initialize messages.
          decode_msg = "";
          instr_state = "";
          instruction_full = "";
          hazard_type = "";
          stall_msg = "";
          instr_flush_msg = "";

          // Determine the type of hazard and generate the appropriate message.
          if (load_use_hazard) begin
            hazard_type = "load-to-use hazard";
          end else if (br_hazard) begin
            hazard_type = "Branch (BR) hazard";
          end else if (b_hazard) begin
            hazard_type = "Branch (B) hazard";
          end

          // Get the full instruction.
          get_full_instruction(.opcode(expected_EX_signals[6:3]), .rs(expected_EX_signals[62:59]), .rt(expected_EX_signals[58:55]), .rd(expected_WB_signals[7:4]), .actual_target(expected_branch_target), .ALU_imm(expected_EX_signals[38:23]), .cc(cc), .instr_name(instruction_full));

          // Verify EX signals.
          verify_EX(.EX_signals(EX_signals), .expected_EX_signals(expected_EX_signals), .stage("DECODE"), .stage_msg(decode_msg));

          // Verify MEM signals.
          verify_MEM(.MEM_signals(MEM_signals), .expected_MEM_signals(expected_MEM_signals), .stage("DECODE"), .stage_msg(decode_msg));

          // Verify WB signals.
          verify_WB(.WB_signals(WB_signals), .expected_WB_signals(expected_WB_signals), .stage("DECODE"), .stage_msg(decode_msg));

          // Verify branch-related signals.
          if (is_branch !== expected_is_branch) begin
              decode_msg = $sformatf("[DECODE] ERROR: is_branch: %b, expected_is_branch: %b.", is_branch, expected_is_branch);
              return;
          end

          if (is_BR !== expected_is_BR) begin
              decode_msg = $sformatf("[DECODE] ERROR: is_BR: %b, expected_is_BR: %b.", is_BR, expected_is_BR);
              return;
          end

          if (branch_target !== expected_branch_target) begin
              decode_msg = $sformatf("[DECODE] ERROR: branch_target: 0x%h, expected_branch_target: 0x%h.", branch_target, expected_branch_target);
              return;
          end

          if (actual_taken !== expected_actual_taken) begin
              decode_msg = $sformatf("[DECODE] ERROR: actual_taken: %b, expected_actual_taken: %b.", actual_taken, expected_actual_taken);
              return;
          end

          if (wen_BTB !== expected_wen_BTB) begin
              decode_msg = $sformatf("[DECODE] ERROR: wen_BTB: %b, expected_wen_BTB: %b.", wen_BTB, expected_wen_BTB);
              return;
          end

          if (wen_BHT !== expected_wen_BHT) begin
              decode_msg = $sformatf("[DECODE] ERROR: wen_BHT: %b, expected_wen_BHT: %b.", wen_BHT, expected_wen_BHT);
              return;
          end

          if (update_PC !== expected_update_PC) begin
              decode_msg = $sformatf("[DECODE] ERROR: update_PC: %b, expected_update_PC: %b.", update_PC, expected_update_PC);
              return;
          end

          // Verify the flush state.
          if (IF_flush !== expected_IF_flush) begin
              decode_msg = $sformatf("[DECODE] ERROR: IF_flush: %b, expected_IF_flush: %b.", IF_flush, expected_IF_flush);
              return;  // Exit task on error
          end

          // Verify the stall state.
          if (IF_ID_stall !== expected_IF_ID_stall) begin
              decode_msg = $sformatf("[DECODE] ERROR: IF_ID_stall: %b, expected_update_PC: %b.", IF_ID_stall, expected_IF_ID_stall);
              return;  // Exit task on error
          end

        // Get the decoded instruction.
        display_decoded_info(.opcode(EX_signals[6:3]), .flag_reg(flag_reg), .rs(EX_signals[62:59]), .rt(EX_signals[58:55]), .rd(WB_signals[7:4]), .ALU_imm(EX_signals[38:23]), .actual_taken(actual_taken), .actual_target(branch_target), .instr_state(instr_state));

        // Print success message.
        decode_msg = $sformatf("[DECODE] SUCCESS: %s", instr_state);

          // If there is a stall at the decode stage, print out the stall along with reason.
          if (IF_ID_stall && !hlt) begin
            stall_msg = $sformatf("[DECODE] STALL: Instruction stalled at decode due to %s.", hazard_type);
          end else if (IF_flush) begin // If the instruction is flushed.
            decode_msg = $sformatf("[DECODE] FLUSH: Instruction flushed at decode (IF) due to mispredicted branch.");
            instr_flush_msg = $sformatf("FLUSHED");
          end
      end
  endtask


  // Subtask: Verify EX Signals.
  task automatic verify_EX(
      input logic [62:0] EX_signals, expected_EX_signals, 
      input string stage,
      output string stage_msg
  );
      logic [3:0] SrcReg1, SrcReg2, ALUOp;
      logic [15:0] ALU_In1, ALU_imm, ALU_In2;
      logic ALUSrc, Z_en, NV_en;

      logic [3:0] expected_SrcReg1, expected_SrcReg2, expected_ALUOp;
      logic [15:0] expected_ALU_In1, expected_ALU_imm, expected_ALU_In2;
      logic expected_ALUSrc, expected_Z_en, expected_NV_en;

      // Unpack EX signals
      {SrcReg1, SrcReg2, ALU_In1, ALU_imm, ALU_In2, ALUOp, ALUSrc, Z_en, NV_en} = EX_signals;
      
      {expected_SrcReg1, expected_SrcReg2, expected_ALU_In1, expected_ALU_imm, expected_ALU_In2,
      expected_ALUOp, expected_ALUSrc, expected_Z_en, expected_NV_en} = expected_EX_signals;

      // Initialize stage_msg message
      stage_msg = ""; 

      // Compare each field
      if (SrcReg1 !== expected_SrcReg1) begin
          stage_msg = $sformatf("[%s] ERROR: SrcReg1 mismatch: 0x%h (expected 0x%h).", stage, SrcReg1, expected_SrcReg1);
          return;
      end

      if (SrcReg2 !== expected_SrcReg2) begin
          stage_msg = $sformatf("[%s] ERROR: SrcReg2 mismatch: 0x%h (expected 0x%h).", stage, SrcReg2, expected_SrcReg2);
          return;
      end

      if (ALU_In1 !== expected_ALU_In1) begin
          stage_msg = $sformatf("[%s] ERROR: ALU_In1 mismatch: 0x%h (expected 0x%h).", stage, ALU_In1, expected_ALU_In1);
          return;
      end

      if (ALU_imm !== expected_ALU_imm) begin
          stage_msg = $sformatf("[%s] ERROR: ALU_imm mismatch: 0x%h (expected 0x%h).", stage, ALU_imm, expected_ALU_imm);
          return;
      end

      if (ALU_In2 !== expected_ALU_In2) begin
          stage_msg = $sformatf("[%s] ERROR: ALU_In2 mismatch: 0x%h (expected 0x%h).", stage, ALU_In2, expected_ALU_In2);
          return;
      end

      if (ALUOp !== expected_ALUOp) begin
          stage_msg = $sformatf("[%s] ERROR: ALUOp mismatch: 0x%h (expected 0x%h).", stage, ALUOp, expected_ALUOp);
          return;
      end

      if (ALUSrc !== expected_ALUSrc) begin
          stage_msg = $sformatf("[%s] ERROR: ALUSrc mismatch: 0b%b (expected 0b%b).", stage, ALUSrc, expected_ALUSrc);
          return;
      end

      if (Z_en !== expected_Z_en) begin
          stage_msg = $sformatf("[%s] ERROR: Z_en mismatch: 0b%b (expected 0b%b).", stage, Z_en, expected_Z_en);
          return;
      end

      if (NV_en !== expected_NV_en) begin
          stage_msg = $sformatf("[%s] ERROR: NV_en mismatch: 0b%b (expected 0b%b).", stage, NV_en, expected_NV_en);
          return;
      end
  endtask


  // Subtask: Verify MEM Signals.
  task automatic verify_MEM(
      input logic [17:0] MEM_signals, expected_MEM_signals,
      input string stage,
      output string stage_msg
  );
      logic [15:0] MemWriteData;
      logic MemEnable, MemWrite;

      logic [15:0] expected_MemWriteData;
      logic expected_MemEnable, expected_MemWrite;

      // Unpack MEM signals
      {MemWriteData, MemEnable, MemWrite} = MEM_signals;
      {expected_MemWriteData, expected_MemEnable, expected_MemWrite} = expected_MEM_signals;

      // Initialize stage message.
      stage_msg = "";

      // Compare each field
      if (MemWriteData !== expected_MemWriteData) begin
          stage_msg = $sformatf("[%s] ERROR: MemWriteData mismatch: 0x%h (expected 0x%h).", stage, MemWriteData, expected_MemWriteData);
          return;
      end

      if (MemEnable !== expected_MemEnable) begin
          stage_msg = $sformatf("[%s] ERROR: MemEnable mismatch: 0b%b (expected 0b%b).", stage, MemEnable, expected_MemEnable);
          return;
      end

      if (MemWrite !== expected_MemWrite) begin
          stage_msg = $sformatf("[%s] ERROR: MemWrite mismatch: 0b%b (expected 0b%b).", stage, MemWrite, expected_MemWrite);
          return;
      end
  endtask


  // Subtask: Verify WB Signals.
  task automatic verify_WB(
      input logic [7:0] WB_signals, expected_WB_signals,
      input string stage,
      output string stage_msg
  );
      logic [3:0] reg_rd;
      logic RegWrite, MemToReg, HLT, PCS;

      logic [3:0] expected_reg_rd;
      logic expected_RegWrite, expected_MemToReg, expected_HLT, expected_PCS;

      // Unpack WB signals
      {reg_rd, RegWrite, MemToReg, HLT, PCS} = WB_signals;
      {expected_reg_rd, expected_RegWrite, expected_MemToReg, expected_HLT, expected_PCS} = expected_WB_signals;

      // Initialize stage message.
      stage_msg = "";

      // Compare each field.
      if (reg_rd !== expected_reg_rd) begin
          stage_msg = $sformatf("[%s] ERROR: reg_rd mismatch: 0x%h (expected 0x%h).", stage, reg_rd, expected_reg_rd);
          return;
      end

      if (RegWrite !== expected_RegWrite) begin
          stage_msg = $sformatf("[%s] ERROR: RegWrite mismatch: 0b%b (expected 0b%b).", stage, RegWrite, expected_RegWrite);
          return;
      end

      if (MemToReg !== expected_MemToReg) begin
          stage_msg = $sformatf("[%s] ERROR: MemToReg mismatch: 0b%b (expected 0b%b).", stage, MemToReg, expected_MemToReg);
          return;
      end

      if (HLT !== expected_HLT) begin
          stage_msg = $sformatf("[%s] ERROR: HLT mismatch: 0b%b (expected 0b%b).", stage, HLT, expected_HLT);
          return;
      end

      if (PCS !== expected_PCS) begin
          stage_msg = $sformatf("[%s] ERROR: PCS mismatch: 0b%b (expected 0b%b).", stage, PCS, expected_PCS);
          return;
      end
  endtask


  // Task: Verifies ID/EX Pipeline Register.
  task automatic verify_ID_EX(
      input logic [104:0] ID_EX_signals, input logic [104:0] expected_ID_EX_signals,
      output string id_ex_message
  );  
      // Initialize message.
      id_ex_message = "";

      // Verify the PC next.
      if (ID_EX_signals[104:89] !== expected_ID_EX_signals[104:89]) begin
        id_ex_message = $sformatf("[ID_EX] ERROR: ID_EX_PC_next: 0x%h, expected_ID_EX_PC_next: 0x%h.", ID_EX_signals[104:89], expected_ID_EX_signals[104:89]);
        return;  // Exit task on error
      end

      // Verify EX signals.
      verify_EX(.EX_signals(ID_EX_signals[88:26]), .expected_EX_signals(expected_ID_EX_signals[88:26]), .stage("ID_EX"), .stage_msg(id_ex_message));

      // Verify MEM signals.
      verify_MEM(.MEM_signals(ID_EX_signals[25:8]), .expected_MEM_signals(expected_ID_EX_signals[25:8]), .stage("ID_EX"), .stage_msg(id_ex_message));

      // Verify WB signals.
      verify_WB(.WB_signals(ID_EX_signals[7:0]), .expected_WB_signals(expected_ID_EX_signals[7:0]), .stage("ID_EX"), .stage_msg(id_ex_message));

      // Print the success message.
      id_ex_message = "[ID_EX] SUCCESS: All signals valid.";
  endtask


  // Task: Verifies the EXECUTE stage operation result and flags.
  task automatic verify_EXECUTE(
      input logic [15:0] Input_A,      
      input logic [15:0] Input_B, 
      input logic [15:0] expected_Input_A,      
      input logic [15:0] expected_Input_B, 
      input logic [15:0] ALU_out,
      input logic Z_set, V_set, N_set,
      input logic [15:0] expected_ALU_out,
      input logic ID_flush, expected_ID_flush,
      input logic br_hazard, b_hazard, load_use_hazard,          
      input logic ZF,                 
      input  logic NF,               
      input  logic VF,               
      input  logic expected_ZF,                
      input  logic expected_VF,               
      input  logic expected_NF,
      output string execute_msg, ex_flush_msg 
  );
     string hazard_type;
    
     // Initialize message.
     execute_msg = "";
     ex_flush_msg = "";
     hazard_type = "";

    // Determine the type of hazard and generate the appropriate message.
    if (load_use_hazard) begin
        hazard_type = "load-to-use hazard";
    end else if (br_hazard) begin
        hazard_type = "Branch (BR) hazard";
    end else if (b_hazard) begin
        hazard_type = "Branch (B) hazard";
    end
      
      // Verify ALU result.
      if (ALU_out !== expected_ALU_out) begin
          execute_msg = $sformatf("[EXECUTE] ERROR: Input_A = 0x%h, Input_B = 0x%h, ALU_out = 0x%h, expected_Input_A = 0x%h, expected_Input_B = 0x%h, expected_ALU_out = 0x%h.", Input_A, Input_B, ALU_out, expected_Input_A, expected_Input_B, expected_ALU_out);
          return;
      end

      /* Verify flag register outputs. */
      if (ZF !== expected_ZF) begin
          execute_msg = $sformatf("[EXECUTE] ERROR: ZF: 0x%h, expected_ZF: 0x%h.", ZF, expected_ZF);
          return;
      end

      if (VF !== expected_VF) begin
          execute_msg = $sformatf("[EXECUTE] ERROR: VF: 0x%h, expected_VF: 0x%h.", VF, expected_VF);
        return;
      end

      if (NF !== expected_NF) begin
        execute_msg = $sformatf("[EXECUTE] ERROR: NF: 0x%h, expected_NF: 0x%h.", NF, expected_NF);
        return;
      end

      // Verify the flush state.
      if (ID_flush !== expected_ID_flush) begin
          execute_msg = $sformatf("[EXECUTE] ERROR: ID_flush: %b, expected_ID_flush: %b.", ID_flush, expected_ID_flush);
          return;  // Exit task on error
       end

       // If there is a flush at the execute stage, print out the flush along with reason.
       if (ID_flush) // If the instruction is flushed.
            ex_flush_msg = $sformatf("[EXECUTE] FLUSH: Instruction flushed at execute (ID) due to %s. ZF = %b, VF = %b, NF = %b.", hazard_type, ZF, VF, NF);
 
        // Display the execution result if no errors are found.
        execute_msg = $sformatf("[EXECUTE] SUCCESS: ZF = %b, VF = %b, NF = %b. Input_A = 0x%h, Input_B = 0x%h, ALU_out = 0x%h, Z_set = %b, V_set = %b, N_set = %b.", ZF, VF, NF, Input_A, Input_B, ALU_out, Z_set, V_set, N_set);
  endtask


  // Task: Verifies the EX/MEM Pipeline Register.
  task automatic verify_EX_MEM(
      input logic [61:0] EX_MEM_signals, input logic [61:0] expected_EX_MEM_signals,
      output string ex_mem_message
  );
    // Initialize message.
    ex_mem_message = "";

      // Verify the PC next.
      if (EX_MEM_signals[61:46] !== expected_EX_MEM_signals[61:46]) begin
        ex_mem_message = $sformatf("[EX_MEM] ERROR: EX_MEM_PC_next: 0x%h, expected_EX_MEM_PC_next: 0x%h.", EX_MEM_signals[61:46] , expected_EX_MEM_signals[61:46]);
        return;  // Exit task on error
      end

      // Verify the ALU output.
      if (EX_MEM_signals[45:30] !== expected_EX_MEM_signals[45:30]) begin
          ex_mem_message = $sformatf("[EX_MEM] ERROR: EX_MEM_ALU_out: 0x%h, expected_EX_MEM_ALU_out: 0x%h.", EX_MEM_signals[45:30], expected_EX_MEM_signals[45:30]);
          return;
      end

      // Verify the SrcReg2.
      if (EX_MEM_signals[29:26] !== expected_EX_MEM_signals[29:26]) begin
          ex_mem_message = $sformatf("[EX_MEM] ERROR: SrcReg2 mismatch: 0x%h (expected 0x%h).", EX_MEM_signals[29:26], expected_EX_MEM_signals[29:26]);
          return;
      end

      // Verify MEM signals.
      verify_MEM(.MEM_signals(EX_MEM_signals[25:8]), .expected_MEM_signals(expected_EX_MEM_signals[25:8]), .stage("EX_MEM"), .stage_msg(ex_mem_message));

      // Verify WB signals.
      verify_WB(.WB_signals(EX_MEM_signals[7:0]), .expected_WB_signals(expected_EX_MEM_signals[7:0]), .stage("EX_MEM"), .stage_msg(ex_mem_message));

      // Print the success message.
      ex_mem_message = "[EX_MEM] SUCCESS: All signals valid.";
  endtask


  // Task: Verifies Memory Signals in the Memory Stage.
  task automatic verify_MEMORY(
      input logic [15:0] EX_MEM_ALU_out,
      input logic [15:0] MemData, expected_MemData,           
      input logic [15:0] MemWriteData, expected_MemWriteData, 
      input logic EX_MEM_MemEnable,
      input logic EX_MEM_MemWrite,
      output string mem_verify_msg
  );
      // Initialize output message
      mem_verify_msg = "";

      // Verify memory data read.
      if (EX_MEM_MemEnable && !EX_MEM_MemWrite) begin
        if (MemData !== expected_MemData) begin
            mem_verify_msg = $sformatf("[MEMORY] ERROR: MemData (Read): 0x%h, expected_MemData: 0x%h.", MemData, expected_MemData);
            return;
        end
      end

      // Verify memory data written.
      if (EX_MEM_MemEnable && EX_MEM_MemWrite) begin
        if (MemData !== expected_MemData) begin
        mem_verify_msg = $sformatf("[MEMORY] ERROR: MemWriteData (Written): 0x%h, expected_MemWriteData: 0x%h.", MemWriteData, expected_MemWriteData);
        return;
        end
      end

      // If all checks pass, print success message.
      if (EX_MEM_MemEnable && EX_MEM_MemWrite) begin
          // Memory write operation
          mem_verify_msg = $sformatf("[MEMORY] SUCCESS: Writing 0x%h to Address: 0x%h.", MemWriteData, EX_MEM_ALU_out);
      end else if (EX_MEM_MemEnable && !EX_MEM_MemWrite) begin
          // Memory read operation
          mem_verify_msg = $sformatf("[MEMORY] SUCCESS: Read 0x%h from Address: 0x%h.", MemData, EX_MEM_ALU_out);
      end else begin
          // No memory operation
          mem_verify_msg = "[MEMORY] SUCCESS: No memory access in this cycle.";
      end

  endtask


  // Task: Verifies the MEM/WB Pipeline Register.
  task automatic verify_MEM_WB(
    input logic [55:0] MEM_WB_signals, input logic [55:0] expected_MEM_WB_signals,
    output string mem_wb_message
  );  
      // Initialize message.
      mem_wb_message = "";

      // Verify the PC next.
      if (MEM_WB_signals[55:40] !== expected_MEM_WB_signals[55:40]) begin
        mem_wb_message = $sformatf("[MEM_WB] ERROR: MEM_WB_PC_next: 0x%h, expected_MEM_WB_PC_next: 0x%h.", MEM_WB_signals[55:40] , expected_MEM_WB_signals[55:40]);
        return;  // Exit task on error
      end

      // Verify the ALU output.
      if (MEM_WB_signals[39:24] !== expected_MEM_WB_signals[39:24]) begin
          mem_wb_message = $sformatf("[MEM_WB] ERROR: MEM_WB_ALU_out: 0x%h, expected_MEM_WB_ALU_out: 0x%h.", MEM_WB_signals[39:24], expected_MEM_WB_signals[39:24]);
          return;
      end

      // Verify the memory data.
      if (MEM_WB_signals[23:8] !== expected_MEM_WB_signals[23:8]) begin
          mem_wb_message = $sformatf("[MEM_WB] ERROR: MEM_WB_MemData: 0x%h, expected_MEM_WB_MemData: 0x%h.", MEM_WB_signals[23:8], expected_MEM_WB_signals[23:8]);
          return;
      end

      // Verify WB signals.
      verify_WB(.WB_signals(MEM_WB_signals[7:0]), .expected_WB_signals(expected_MEM_WB_signals[7:0]), .stage("MEM_WB"), .stage_msg(mem_wb_message));

      // Print the success message.
      mem_wb_message = "[MEM_WB] SUCCESS: All signals valid.";
  endtask


  // Task: Verifies Write-Back (WB) Stage Signals.
  task automatic verify_WRITEBACK(
      input logic [3:0] MEM_WB_DstReg,
      input logic MEM_WB_RegWrite,
      input logic [15:0] RegWriteData, expected_RegWriteData,
      output string wb_verify_msg
  );
      // Initialize output message
      wb_verify_msg = "";

      // Verify register data to be written.
      if (RegWriteData !== expected_RegWriteData) begin
          wb_verify_msg = $sformatf("[WRITE-BACK] ERROR: RegWriteData: 0x%h, expected: 0x%h.", RegWriteData, expected_RegWriteData);
          return;
      end

      // If all checks pass, output success message.
      if (MEM_WB_RegWrite) begin
        wb_verify_msg = $sformatf("[WRITE-BACK] SUCCESS: Register R%0d written with data: 0x%h.", MEM_WB_DstReg, RegWriteData);
      end else begin
        wb_verify_msg = "[WRITE-BACK] SUCCESS: No register write in this cycle.";
      end
  endtask

endpackage  
