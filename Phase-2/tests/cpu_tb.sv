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


parameter MAX_INSTR = 32;  // Max number of instructions in pipeline
parameter MAX_MSGS  = 16;  // Max messages per instruction

string fetch_msgs[MAX_INSTR][MAX_MSGS];   // Fetch messages per instruction
string decode_msgs[MAX_INSTR][MAX_MSGS];  // Decode messages per instruction
string instruction_text[MAX_INSTR];       // Stores instruction text

int inst_id = 0;          // Tracks current instruction ID
int msg_index[MAX_INSTR]; // Tracks message index per instruction

// Reset logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        inst_id = 0;
        for (int i = 0; i < MAX_INSTR; i++) msg_index[i] = 0;
    end
end

// Fetch Tracking
always @(posedge clk) begin
    if (rst_n) begin
        string fetch_msg;
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

        // Store fetch message for current instruction
        fetch_msgs[inst_id][msg_index[inst_id]] = fetch_msg;

        // If stall, increment msg_index only
        if (iDUT.PC_stall) begin
            msg_index[inst_id] = msg_index[inst_id] + 1;
        end
    end
end

// Decode Tracking
always @(posedge clk) begin
    if (rst_n) begin
        string decode_msg, instr_full;
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
            .instruction_full(instr_full)
        );

        // Store decode message for current instruction
        decode_msgs[inst_id][msg_index[inst_id]] = decode_msg;
        instruction_text[inst_id] = instr_full;

        // If stall, increment msg_index only
        if (iDUT.IF_ID_stall) begin
            msg_index[inst_id] = msg_index[inst_id] + 1;
        end
        // Otherwise, move to the next instruction
        else begin
            inst_id = inst_id + 1;
            msg_index[inst_id] = 0;  // Reset message index for new instruction
        end
    end
end

// Printing messages when an instruction completes
always @(posedge clk) begin
    if (rst_n) begin
        if (inst_id > 0) begin
            int i = inst_id - 1; // Last completed instruction
            $display("========================================================");
            $display("| Instruction: %s |", instruction_text[inst_id-1]);
            $display("========================================================");

            // Print FETCH messages
            for (int j = 0; j <= msg_index[inst_id - 1]; j++) begin
                $display("| %s", fetch_msgs[inst_id - 1][j]);
            end

            // Print DECODE messages
            for (int j = 0; j <= msg_index[inst_id - 1]; j++) begin
                $display("| %s", decode_msgs[inst_id - 1][j]);
            end

            $display("========================================================");
        end
    end
end

  // Generate clock signal with 10 ns period
  always 
    #5 clk = ~clk;

endmodule