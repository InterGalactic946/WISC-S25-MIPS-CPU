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
  string fetch_msg, fetch_stall_msg, decode_msg, decode_stall_msg, instruction_full_msg, id_ex_msg, 
         execute_msg, ex_mem_msg, mem_msg, mem_wb_msg, wb_msg, pc_stall_msg, if_id_stall_msg, if_flush_msg, id_flush_msg, instruction_header;

  // reg [255:0] fetch_stage_msg, decode_stage_msg, full_instruction_msg;

  // // Assume tracking of 71 instructions, with a capacity of storing 5 messages per stage (fetch, deocde).
  string fetch_msgs[0:71][0:4];
  string decode_msgs[0:71][0:4][0:1];
  string execute_msgs[0:71];
  string mem_msgs[0:71];
  string wb_msgs[0:71];
  
  // // Indices into the arrays.
  // integer fetch_id, decode_id;
  // integer fetch_msg_indices[72]; // Tracks message indices per instruction
  // integer decode_msg_indices[72]; // Tracks message indices per instruction

    integer instr_id, fetch_id, decode_id, execute_id, memory_id, wb_id, max_index, print, msg_index;
    logic valid_fetch, valid_decode, valid_execute, valid_memory, valid_wb;
    debug_info_t pipeline_msgs[0:71];

//   // Store the messages for FETCH and DECODE stages
// reg [31:0] instruction_cycle; // Store the cycle when the instruction is completed

// logic valid_fetch, valid_decode;



  
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
  //   .fetch_msg(fetch_msg),
  //   .decode_msg(decode_msg),
  //   .instruction_full_msg(instruction_full_msg),
  //   .execute_msg(execute_msg),
  //   .mem_msg(mem_msg),
  //   .wb_msg(wb_msg),
  //   .stall(stall),
  //   .flush(flush)
  // );

  // // Instantiate the DUT
  // Dynamic_Pipeline_Unit iDPT (
  //     .clk(clk),
  //     .rst(rst),
  //     .PC_stall(iDUT.PC_stall),
  //     .IF_ID_stall(iDUT.IF_ID_stall),
  //     .IF_flush(iDUT.IF_flush),
  //     .fetch_msg(fetch_msg),
  //     .decode_msg(decode_msg),
  //     .execute_msg(execute_msg),
  //     .memory_msg(mem_msg),
  //     .wb_msg(wb_msg),
  //     .instruction_full_msg(instruction_full_msg)
  // );

  // Test procedure to apply stimulus and check responses.
  initial begin
    // Initialize the testbench
    Initialize(.clk(clk), .rst_n(rst_n));

    // Run the simulation for each instruction in the instruction memory until HLT reaches WB.
    TimeoutTask(.sig(hlt), .clk(clk), .clks2wait(1000000), .signal("HLT"));

    // repeat(100) @(posedge clk) begin
    //   // $display("ZF = %b, VF = %b, NF = %b. Cycle: %0t", iDUT.ZF, iDUT.VF, iDUT.NF, $time / 10);
    // end

    // If we reached here, that means all test cases were successful
    $display("YAHOO!! All tests passed.");
    $stop();
  end

  // // We stall on PC or IF.
  // assign stall = iDUT.PC_stall || iDUT.IF_ID_stall;

  // // We flush IF, or ID stage.
  // assign flush = iDUT.IF_flush || iDUT.ID_flush;

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



// First Always Block: Tracks the pipeline and increments IDs
always @(negedge clk) begin
    if (rst) begin
        fetch_id   <= 0;
        decode_id  <= -1;
        execute_id <= -2;
        memory_id  <= -3;
        wb_id      <= -4;
    end else if (iDUT.PC_stall && iDUT.IF_ID_stall) begin
        fetch_id <= fetch_id; // Stall the instruction in fetch
        decode_id <= decode_id; // stall the instruction in decode
        execute_id <= decode_id;  // Pass the decode_id to execute_id
        memory_id  <= execute_id; // Pass the execute_id to memory_id
        wb_id      <= memory_id;  // Pass the memory_id to wb_id
    end else if (iDUT.PC_stall && !iDUT.IF_ID_stall) begin
        fetch_id <= fetch_id; // Stall the instruction in fetch
        decode_id <= fetch_id; // Pass the fetch_id to decode_id
        execute_id <= decode_id;  // Pass the decode_id to execute_id
        memory_id  <= execute_id; // Pass the execute_id to memory_id
        wb_id      <= memory_id;  // Pass the memory_id to wb_id  
    end else if (!iDUT.PC_stall && !iDUT.IF_ID_stall) begin
        fetch_id <= fetch_id + 1; // Fetch the next instruction
        decode_id <= fetch_id; // Pass the fetch_id to decode_id
        execute_id <= decode_id;  // Pass the decode_id to execute_id
        memory_id  <= execute_id; // Pass the execute_id to memory_id
        wb_id      <= memory_id;  // Pass the memory_id to wb_id  
    end    
end

// // Second Always Block: Propagate the valid signals across stages
// always @(posedge clk) begin
//     if (rst) begin
//         valid_decode  <= 0;
//         valid_execute <= 0;
//         valid_memory  <= 0;
//         valid_fetch   <= 1;
//         valid_wb      <= 0;
//     end else if (!stall) begin
//         valid_fetch <= 1;  // Continue fetching if not stalled
//     end else begin
//         valid_fetch <= 0;
//     end

//     // Propagate the valid signals correctly.
//     valid_decode  <= valid_fetch;
//     valid_execute <= valid_decode;
//     valid_memory  <= valid_execute;
//     valid_wb      <= valid_memory;
// end

// // Third Always Block: Stores pipeline messages, with stall and flush checks
// always @(negedge clk) begin
//     if (valid_fetch) begin
//         pipeline_msgs[fetch_id].fetch_msg   = fetch_msg;
//         pipeline_msgs[fetch_id].fetch_cycle = $time / 10;
//     end
//     if (valid_decode) begin
//         pipeline_msgs[decode_id].decode_msg[0] = decode_msg;
//         pipeline_msgs[decode_id].decode_msg[1] = instruction_full_msg;
//         pipeline_msgs[decode_id].decode_cycle  = $time / 10;
//     end
//     if (valid_execute) begin
//         pipeline_msgs[execute_id].execute_msg   = execute_msg;
//         pipeline_msgs[execute_id].execute_cycle = $time / 10;
//     end
//     if (valid_memory) begin
//         pipeline_msgs[memory_id].memory_msg   = mem_msg;
//         pipeline_msgs[memory_id].memory_cycle = $time / 10;
//     end
//     if (valid_wb) begin
//         pipeline_msgs[wb_id].wb_msg   = wb_msg;
//         pipeline_msgs[wb_id].wb_cycle = $time / 10;
//     end
// end

// // Fourth Always Block: Print the pipeline messages at negedge clk
// always @(negedge clk) begin
//     if (!rst && valid_wb) begin
//         $display("==========================================================");
//         $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline_msgs[wb_id].decode_msg[1], $time / 10);
//         $display("==========================================================");
//         $display("| %s @ Cycle: %0t", pipeline_msgs[wb_id].fetch_msg, pipeline_msgs[wb_id].fetch_cycle);
//         $display("| %s @ Cycle: %0t", pipeline_msgs[wb_id].decode_msg[0], pipeline_msgs[wb_id].decode_cycle);
//         $display("| %s @ Cycle: %0t", pipeline_msgs[wb_id].execute_msg, pipeline_msgs[wb_id].execute_cycle);
//         $display("| %s @ Cycle: %0t", pipeline_msgs[wb_id].memory_msg, pipeline_msgs[wb_id].memory_cycle);
//         $display("| %s @ Cycle: %0t", pipeline_msgs[wb_id].wb_msg, pipeline_msgs[wb_id].wb_cycle);
//         $display("==========================================================\n");
//     end
// end

// Always block for verify_FETCH stage
always @(posedge clk) begin
    if (rst_n) begin
      string ftch_msg;

        // Verify FETCH stage logic
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
            .stage_msg(ftch_msg)
        );

        // if (!stall && valid_fetch)
        //   fetch_msgs[fetch_id][0] = {"|", ftch_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};
        // else if (stall)
        //   fetch_msgs[fetch_id][msg_index] = {"|", ftch_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};

        fetch_msg = {$sformatf("ID: %0d. ", fetch_id), "|", ftch_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};
        // fetch_stall_msg <= ftch_stall_msg;
        // $display("%s, Cycle: %0t.", fetch_msg, $time / 10);
        // if (valid_fetch || stall) begin
        //   pipeline_msgs[fetch_id].fetch_msgs[msg_index] = fetch_msg;
        //   pipeline_msgs[fetch_id].fetch_cycles[msg_index] = $time / 10;
        // end
        $display(fetch_msg);
    end
end

// // First Always Block: Tracks the pipeline and increments IDs
// always @(posedge clk) begin
//     if (rst) begin
//         fetch_id <= 0;
//         decode_id <= 0;
//         execute_id <= 0;
//         memory_id <= 0;
//         wb_id <= 0;
//     end else if (valid_fetch) begin
//         // Only increment fetch_id when there's a valid fetch.
//         fetch_id <= fetch_id + 1;
//     end

//     // Update pipeline stages.
//     decode_id <= fetch_id;   // Pass the fetch_id to decode_id
//     execute_id <= decode_id; // Pass the decode_id to execute_id
//     memory_id <= execute_id; // Pass the execute_id to memory_id
//     wb_id <= memory_id;      // Pass the memory_id to wb_id
// end

// always @(negedge clk) begin
//   if (!rst_n) begin
//     valid_fetch <= 1;
//     valid_decode <= 0;
//     valid_execute <= 0; 
//     valid_memory <= 0;
//     valid_wb <= 0;
//   end else if (!stall)
//     valid_fetch <= 1;
    
//     valid_decode <= valid_fetch;
//     valid_execute <= valid_decode; 
//     valid_memory <= valid_execute;
//     valid_wb = valid_memory;
// end

// always @(posedge clk) begin
//   if (!rst_n) begin
//     msg_index <= 1;
//   end else if (stall)
//     msg_index <= msg_index + 1;
// end


// always @(posedge clk) begin
//   if (valid_wb) begin

//     for (int i = 0; i < 5; i = i + 1) begin
//         max_index = 0;
//         if (decode_msgs[wb_id][i][1] !== "")
//           max_index = max_index + 1;
//     end
//   $display("==========================================================");
//   $display("| Instruction: %s | Completed At Cycle: %0t |", decode_msgs[wb_id][max_index][1], $time / 10);
//   $display("==========================================================");
//   for (int i = 0; i < 5; i = i+1)
//     if (fetch_msgs[wb_id][i] !== "")
//       $display("%s", fetch_msgs[wb_id][i]);
//   for (int i = 0; i < 5; i = i+1)
//     if (decode_msgs[wb_id][i][0] !== "")        
//       $display("%s", decode_msgs[wb_id][i][0]);
//   $display("%s", execute_msgs[wb_id]);
//   $display("%s", mem_msgs[wb_id]);
//   $display("%s", wb_msgs[wb_id]);
//   $display("==========================================================\n");
//   end

// end


// // First Always Block: Tracks the pipeline and increments IDs
// always @(posedge clk) begin
//     if (rst) begin
//         fetch_id <= 0;
//         decode_id <= 0;
//         execute_id <= 0;
//         memory_id <= 0;
//         wb_id <= 0;
//     end else if (valid_fetch) begin
//         // Only increment fetch_id when there's a valid fetch.
//         fetch_id <= fetch_id + 1;
//         // Update pipeline stages.
//         decode_id <= fetch_id;   // Pass the fetch_id to decode_id
//         execute_id <= decode_id; // Pass the decode_id to execute_id
//         memory_id <= execute_id; // Pass the execute_id to memory_id
//         wb_id <= memory_id;      // Pass the memory_id to wb_id
//     end
// end


// always @(posedge clk) begin
//     if (rst) begin
//         valid_decode <= 0;
//         valid_execute <= 0;
//         valid_memory <= 0;
//         valid_fetch <= 1;   // Assuming fetch is always valid after reset
//         valid_wb <= 0;
//     end else if (!stall) begin
//         // Propagate the valid signal to future stages only when not stalled
//         valid_decode <= valid_fetch;
//         valid_execute <= valid_decode;
//         valid_memory <= valid_execute;
//         valid_wb <= valid_memory;
//     end else begin
//         // If stall is active, clear the signals and stop propagation
//         valid_fetch <= 0;  // This will prevent further instruction fetch
//         valid_decode <= 0; 
//         valid_execute <= 0;
//         valid_memory <= 0;
//         valid_wb <= 0;
//     end
// end

// always @(posedge clk) begin
//   if (rst || !stall) begin
//     msg_index <= 0;
//   end else if (stall)
//     msg_index <= msg_index + 1;
// end

// Always block for verify_DECODE stage
always @(posedge clk) begin
    if (rst_n) begin
      string dcode_msg, instr_full_msg, dcode_stall_msg;

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
            
            .decode_msg(dcode_msg),
            .instruction_full(instr_full_msg)
        );

        // // // Correct DECODE cycle tracking (Fetch happens one cycle earlier)
        // if (!stall && !flush) begin
        //   decode_msgs[decode_id][0][0] = {"|", dcode_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};
        //   decode_msgs[decode_id][0][1] = {instr_full_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};
        // end else if (stall || flush) begin
        //   decode_msgs[decode_id][msg_index][0] = {"|", dcode_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};
        //   decode_msgs[decode_id][msg_index][1] = instr_full_msg;
        // end

        // decode_msg = dcode_msg;
        decode_msg = {$sformatf("ID: %0d. ", decode_id), "|", dcode_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};
        // decode_stall_msg <= dcode_stall_msg;
        instruction_full_msg = {$sformatf("ID: %0d. ", decode_id), instr_full_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};

        // if (valid_decode || stall) begin
        //   pipeline_msgs[decode_id].decode_msgs[msg_index][0] = decode_msg;
        //   pipeline_msgs[decode_id].decode_msgs[msg_index][1] = instruction_full_msg;
        //   pipeline_msgs[decode_id].decode_cycles[msg_index] = $time / 10;
        // end

        $display(decode_msg);
        $display(instruction_full_msg);
        // $display(decode_stall_msg);
    end
end


  // Always block for verify_EXECUTE stage
  always @(posedge clk) begin
    if (rst_n) begin
      string ex_msg;

      verify_EXECUTE(
        .Input_A(iDUT.iEXECUTE.iALU.Input_A),
        .Input_B(iDUT.iEXECUTE.iALU.Input_B),
        .expected_Input_A(iMODEL.iEXECUTE.iALU_model.Input_A),
        .expected_Input_B(iMODEL.iEXECUTE.iALU_model.Input_B),
        .ALU_out(iDUT.ALU_out),
        .ID_flush(iDUT.ID_flush),
        .expected_ID_flush(iMODEL.ID_flush),
        .br_hazard(iMODEL.iHDU.BR_hazard),
        .b_hazard(iMODEL.iHDU.B_hazard),
        .load_use_hazard(iMODEL.iHDU.load_to_use_hazard),
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

      // if (valid_execute)
      execute_msg = {$sformatf("ID: %0d. ", execute_id), "|", ex_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};

      // execute_msg = ex_msg;

      // if (valid_execute) begin
      //   pipeline_msgs[execute_id].execute_msg = execute_msg;
      //   pipeline_msgs[execute_id].execute_cycle = $time / 10;
      // end

      $display(execute_msg);
end
    end
  //end


  // Always block for verify_MEMORY stage
  always @(posedge clk) begin
    if (rst_n) begin
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
      
      // if (valid_memory)
      //   mem_msgs[memory_id] = {"|", mem_verify_msg , " @ Cycle: ", $sformatf("%0d", ($time/10))};

      mem_msg = {$sformatf("ID: %0d. ", memory_id), "|", mem_verify_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};

      // if (valid_memory) begin
      //   pipeline_msgs[memory_id].memory_msg = mem_msg;
      //   pipeline_msgs[memory_id].memory_cycle = $time / 10;
      // end
      $display(mem_msg);
    end
  end


    // always @(posedge clk)
    //     if (rst)
    //         print <= 1'b0;
    //     else if (valid_wb)
    //         print <= 1'b1;
    //     else
    //         print <= 1'b0;
        

    // // Print the message for each instruction.
    // always @(posedge clk) begin
    //     if (print) begin
    //         for (int i = 0; i < 5; i = i + 1) begin
    //             max_index = 0;
    //             if (pipeline_msgs[wb_id].decode_msgs[i][1] !== "")
    //                 max_index = max_index + 1;
    //         end
    //         $display("==========================================================");
    //         $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline_msgs[wb_id].decode_msgs[max_index][1], $time / 10);
    //         $display("==========================================================");
    //         for (int i = 0; i < 5; i = i+1)
    //             if (pipeline_msgs[wb_id].fetch_msgs[i] !== "")
    //                 $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].fetch_msgs[i], pipeline_msgs[wb_id].fetch_cycles[i]);
    //         // $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].fetch_msgs[i], pipeline_msgs[wb_id].fetch_cycle);            
    //         for (int i = 0; i < 5; i = i+1)
    //             if (pipeline_msgs[wb_id].decode_msgs[i][0] !== "")
    //                 $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].decode_msgs[i][0], pipeline_msgs[wb_id].decode_cycles[i]);
    //         // $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].decode_msg[0], pipeline_msgs[wb_id].decode_cycle);
    //         $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].execute_msg, pipeline_msgs[wb_id].execute_cycle);
    //         $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].memory_msg, pipeline_msgs[wb_id].memory_cycle);
    //         $display("|%s @ Cycle: %0t", pipeline_msgs[wb_id].wb_msg, pipeline_msgs[wb_id].wb_cycle);
    //         $display("==========================================================\n");
    //     end
    // end


  // Always block for verify_WRITEBACK stage
  always @(posedge clk) begin
    if (rst_n) begin
      string wbb_msg;
      verify_WRITEBACK(
        .MEM_WB_DstReg(iDUT.MEM_WB_reg_rd),
        .MEM_WB_RegWrite(iDUT.MEM_WB_RegWrite),
        .RegWriteData(iDUT.RegWriteData),
        .expected_RegWriteData(iMODEL.RegWriteData),
        
        .wb_verify_msg(wbb_msg)
      );
      
      // if (valid_wb)
      wb_msg = {$sformatf("ID: %0d. ", wb_id), "|", wbb_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};

      // wb_msg = wbb_msg;

      // if (valid_wb) begin
      //   pipeline_msgs[wb_id].wb_msg = wb_msg;
      //   pipeline_msgs[wb_id].wb_cycle = $time / 10;
      // end

      $display(wb_msg);
    end
  end



  // Generate clock signal with 10 ns period
  always 
    #5 clk = ~clk;

endmodule