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
  string decode_msgs[0:71][0:4];
  
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
            .stage_msg(fetch_msg)
        );

        // Store message for FETCH stage at the appropriate index
        fetch_msgs[fetch_id][fetch_msg_indices[fetch_id]] <= $sformatf("|%s @ Cycle: %0t", fetch_msg, $time/10);
    end
end

// Get the valid signal
always @(posedge clk) begin
    if (!rst_n) begin
        valid_fetch  <= 1'b0;
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
        if (valid_fetch) fetch_id  <= fetch_id + 1; 
        if (valid_decode) decode_id <= decode_id + 1;
    end
end

// Get the message index counter, incremented only on stall
always @(posedge clk) begin
    if (!rst_n) begin
        fetch_msg_indices <= '{default: 0};
        decode_msg_indices <= '{default: 0};
    end else if (iDUT.PC_stall) begin
        // Increment fetch message index on PC stall
        fetch_msg_indices[fetch_id] <= fetch_msg_indices[fetch_id] + 1;
    end else if (iDUT.IF_ID_stall) begin
        // Increment decode message index on IF/ID stall
        decode_msg_indices[decode_id] <= decode_msg_indices[decode_id] + 1;
    end else begin
        // Reset message index to 0 when no stall
        fetch_msg_indices[fetch_id] <= 0;
        decode_msg_indices[decode_id] <= 0;
    end
end

// Always block to print fetch messages (after storing them)
always @(posedge clk) begin
    if (rst_n) begin
      if (valid_decode) begin
        // Print all stored fetch messages
        for (int i = 0; i < 5; i = i + 1) begin
            for (int j = 0; j < fetch_msg_indices[i]; j = j + 1) begin
                $display("%s", i, j, fetch_msgs[i][j]);
            end
        end
      end
    end
end


  // Always block to print fetch messages when both fetch and decode are valid
  always @(posedge clk) begin
      if (rst_n) begin
          // Ensure that the queues have valid fetch and decode messages before printing
          if (fetch_id > 0 && decode_id > 0 && valid_decode) begin
              integer i, j;
              string fetch_msg_out, decode_msg_out, instr_out;
              
              // Print the instruction details for each instruction
              for (i = 0; i < fetch_id; i = i + 1) begin
                  // Print all fetch messages for the current instruction
                  for (j = 0; j < MAX_MSGS; j = j + 1) begin
                      if (fetch_msgs[i][j] != "") begin  // Only print non-empty messages
                          $display("========================================================");
                          $display("| Instruction: %s | Fetch Message @ Cycle: %0t |", instr_out, $time/10);
                          $display("========================================================");
                          $display("| %s", fetch_msgs[i][j]);
                      end
                  end
              end

              // Similarly, you can print decode messages if needed
              for (i = 0; i < decode_id; i = i + 1) begin
                  for (j = 0; j < MAX_MSGS; j = j + 1) begin
                      if (decode_msgs[i][j] != "") begin
                          $display("========================================================");
                          $display("| Instruction: %s | Decode Message @ Cycle: %0t |", instr_out, $time/10);
                          $display("========================================================");
                          $display("| %s", decode_msgs[i][j]);
                      end
                  end
              end
          end
      end
  end



  // Generate clock signal with 10 ns period
  always 
    #5 clk = ~clk;

endmodule