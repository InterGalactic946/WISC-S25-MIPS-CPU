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

  // reg [255:0] fetch_stage_msg, decode_stage_msg, full_instruction_msg;

  // Assume tracking of 71 instructions, with a capacity of storing 5 messages per stage (fetch, deocde).
  string fetch_msgs[0:71][0:4];
  string decode_msgs[0:71][0:4][0:1];
  
  // Indices into the arrays.
  integer fetch_id, decode_id;
  integer fetch_msg_indices[72]; // Tracks message indices per instruction
  integer decode_msg_indices[72]; // Tracks message indices per instruction

//   // Store the messages for FETCH and DECODE stages
// reg [31:0] instruction_cycle; // Store the cycle when the instruction is completed

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

        // Store message for FETCH stage at the appropriate index
        // fetch_msgs[fetch_id][fetch_msg_indices[fetch_id]] = $sformatf("|%s @ Cycle: %0t", fetch_msg, $time/10);
        fetch_msg <= $sformatf("%s @ Cycle: %0t", ftch_msg, $time/10);
    end
end



// Always block for verify_DECODE stage
always @(posedge clk) begin
    if (rst_n) begin
      string dcode_msg, instr_full_msg;

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

        // Correct DECODE cycle tracking (Fetch happens one cycle earlier)
        decode_msg <= $sformatf("%s @ Cycle: %s", dcode_msg, $sformatf("%0d", ($time/10) - 1));
        instruction_full_msg <= $sformatf("%s", instr_full_msg);
    end
end


// Get the valid signal
always @(posedge clk) begin
    if (!rst_n) begin
        valid_fetch  <= 1'b1;
        valid_decode <= 1'b0;
    end else begin
        valid_fetch  <= ~stall; // Fetch is valid when no stall
        valid_decode <= valid_fetch; // Decode follows fetch
    end
end

// Increment instruction indices
always @(posedge clk) begin
    if (!rst_n) begin
        fetch_id  <= 0;
        decode_id <= 0;
    end else begin
        if (valid_fetch) fetch_id <= fetch_id + 1; 
        decode_id <= fetch_id;
    end
end


// Get the message index counter, incremented only on stall
always @(posedge clk) begin
    if (!rst_n) begin
        fetch_msg_indices <= '{default: 0};
        decode_msg_indices <= '{default: 0};
    end else if (stall) begin
        // Increment fetch message index on PC stall
        fetch_msg_indices[fetch_id] <= fetch_msg_indices[fetch_id] + 1;
        // Increment decode message index on IF/ID stall
        decode_msg_indices[decode_id] <= decode_msg_indices[decode_id] + 1;
    end
end


// Always block to print fetch messages (after storing them)
always @(negedge clk) begin
    if (valid_fetch) begin // Print during the fetch stage if valid_fetch is active
      fetch_msgs[fetch_id][fetch_msg_indices[fetch_id]] <= fetch_msg;
      $display(fetch_msg);
    end else if (valid_decode) begin
      decode_msgs[decode_id][decode_msg_indices[decode_id]][0] = decode_msg;
      decode_msgs[decode_id][decode_msg_indices[decode_id]][1] = instruction_full_msg;
    end

     $display("==========================================================");
     $display("| Instruction: %s | Completed At Cycle: %0t |", decode_msgs[decode_id][decode_msg_indices[decode_id]][1], $time / 10);
      $display("==========================================================");
      // Print all stored fetch messages for the current fetch_id
      for (int i = 0; i <= fetch_msg_indices[decode_id]; i = i + 1) begin
            $display("|%s", fetch_msgs[decode_id][i]);
      end

      // Print all stored decode messages for the current decode_id
      for (int i = 0; i <= decode_msg_indices[decode_id]; i = i + 1) begin
           $display("|%s", decode_msgs[decode_id][i][0]);
      end
end



  // Generate clock signal with 10 ns period
  always 
    #5 clk = ~clk;

endmodule