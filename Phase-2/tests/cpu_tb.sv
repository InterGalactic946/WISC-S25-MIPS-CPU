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
  string fetch_msg, fetch_stall_msg, decode_msg, decode_stall_msg, instruction_full_msg, instr_flush_msg, id_ex_msg, 
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
    logic valid_fetch, valid_decode, valid_execute, valid_memory, valid_wb, IF_flush, expected_IF_flush, ID_flush, expected_ID_flush;
    logic load_to_use_hazard, expected_load_to_use_hazard, B_hazard, expected_B_hazard, BR_hazard, expected_BR_hazard;
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
  //   .stall(stall)
  // );

  assign stall = iDUT.PC_stall && iDUT.IF_ID_stall;

  // Instantiate the DUT
  // Dynamic_Pipeline_Unit iDPT (
  //     .clk(clk),
  //     .rst(rst),
  //     .fetch_msg(fetch_msg),
  //     .decode_msg(decode_msg),
  //     .execute_msg(execute_msg),
  //     .memory_msg(mem_msg),
  //     .wb_msg(wb_msg),
  //     .stall(stall),
  //     .instruction_full_msg(instruction_full_msg)
  // );

  // Test procedure to apply stimulus and check responses.
  initial begin
    // Initialize the testbench
    Initialize(.clk(clk), .rst_n(rst_n));

    // Run the simulation for each instruction in the instruction memory until HLT reaches WB.
    // TimeoutTask(.sig(hlt), .clk(clk), .clks2wait(1000000), .signal("HLT"));

    repeat(100) @(posedge clk);
    //   // $display("ZF = %b, VF = %b, NF = %b. Cycle: %0t", iDUT.ZF, iDUT.VF, iDUT.NF, $time / 10);
    // end

    // If we reached here, that means all test cases were successful
    $display("YAHOO!! All tests passed.");
    $stop();
  end

    int MAX_INSTR = 5;  // Max instructions in pipeline

    // Define pipeline stages
    typedef enum {FETCH, DECODE, EXECUTE, MEMORY, WRITEBACK, EMPTY} stage_t;

    // Define struct for instruction tracking
    typedef struct {
        stage_t stage;
        string fetch_msgs[0:4], decode_msgs[0:4], instr_full_msg, execute_msg, memory_msg, wb_msg;
        bit print;
    } instr_t;

    // Pipeline: 1D array to track each instruction's stage
    instr_t pipeline[5];
    int num_instr_in_pipeline;  // Number of instructions in the pipeline

    // Simulate pipeline execution
    always_ff @(posedge clk, posedge rst) begin
        if (rst)
            num_instr_in_pipeline <= 1;
        else if (num_instr_in_pipeline < MAX_INSTR && !stall)
            num_instr_in_pipeline <= num_instr_in_pipeline + 1;
    end

    // Simulate pipeline execution
    always_ff @(posedge clk) begin
        if (rst || !stall)
            msg_index <= 0;
        else if (stall)
            msg_index <= msg_index + 1;
    end
        

    // Simulate pipeline execution
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < MAX_INSTR; i++) begin
                if (i === 0)
                    pipeline[i] <= '{FETCH, '{default: ""}, '{default: ""}, "", "", "", "", 0};
                else
                    pipeline[i] <= '{EMPTY, '{default: ""}, '{default: ""}, "", "", "", "", 0};
            end
        end else begin
            // Insert new instruction at the first empty spot (this is where num_instr_in_pipeline is the index of the empty spot)
            pipeline[num_instr_in_pipeline - 1] <= '{FETCH, '{default: ""}, '{default: ""}, "", "", "", "", 0};  // New instruction in FETCH stage

               // Handle stall during DECODE stage
            for (int i = 0; i < num_instr_in_pipeline; i++) begin
                case (pipeline[i].stage)
                    FETCH: begin
                        verify_fetch(.fetch_msg(pipeline[i].fetch_msgs[msg_index]), .stall_msg());
                        pipeline[i].instr_full_msg = "";
                        pipeline[i].decode_msgs[msg_index] = "";  // Clear other stage messages
                        pipeline[i].execute_msg = "";
                        pipeline[i].memory_msg = "";
                        pipeline[i].wb_msg = "";
                    end
                    DECODE: begin
                        pipeline[i].decode_msgs[msg_index] = decode_msg;
                        verify_decode(.decode_msg(pipeline[i].decode_msgs[msg_index]), .decode_stall_msg(), .instr_full_msg(pipeline[i].instr_full_msg));
                        pipeline[i].fetch_msgs = pipeline[i].fetch_msgs; 
                        pipeline[i].execute_msg = "";
                        pipeline[i].memory_msg = "";
                        pipeline[i].wb_msg = "";
                    end
                    EXECUTE: begin
                        verify_execute(.execute_msg(pipeline[i].execute_msg), .ex_flush_msg());  // Only message outputs
                        pipeline[i].instr_full_msg = pipeline[i].instr_full_msg;
                        pipeline[i].fetch_msgs = pipeline[i].fetch_msgs; 
                        pipeline[i].decode_msgs = pipeline[i].decode_msgs;
                        pipeline[i].memory_msg = "";
                        pipeline[i].wb_msg = "";
                    end
                    MEMORY: begin
                        verify_memory(.memory_msg(pipeline[i].memory_msg));  // Only passing the memory message output
                        pipeline[i].instr_full_msg = pipeline[i].instr_full_msg;
                        pipeline[i].fetch_msgs = pipeline[i].fetch_msgs; 
                        pipeline[i].decode_msgs = pipeline[i].decode_msgs;
                        pipeline[i].execute_msg = pipeline[i].execute_msg;
                        pipeline[i].wb_msg = "";
                    end
                    WRITEBACK: begin
                        verify_writeback(.wb_msg(pipeline[i].wb_msg));  // Only passing the WB message output
                        pipeline[i].instr_full_msg = pipeline[i].instr_full_msg;
                        pipeline[i].fetch_msgs = pipeline[i].fetch_msgs; 
                        pipeline[i].decode_msgs = pipeline[i].decode_msgs;
                        pipeline[i].execute_msg = pipeline[i].execute_msg;
                        pipeline[i].memory_msg = pipeline[i].memory_msg;
                    end
                endcase
            end

            // Update stages for each instruction.
            for (int i = 0; i < num_instr_in_pipeline; i++) begin
                case (pipeline[i].stage)
                    EMPTY: begin
                        if (!stall)
                            pipeline[i].stage <= FETCH;
                        else
                            pipeline[i].stage <= EMPTY;
                    end
                    FETCH: begin
                        if (!stall)
                            pipeline[i].stage <= DECODE;
                        else
                            pipeline[i].stage <= FETCH;
                    end
                    DECODE: begin
                        if (!stall)
                            pipeline[i].stage <= EXECUTE;
                        else
                            pipeline[i].stage <= DECODE;
                    end
                    EXECUTE:   pipeline[i].stage <= MEMORY;
                    MEMORY:    pipeline[i].stage = WRITEBACK;
                    WRITEBACK: begin
                        pipeline[i].print <= 1;
                        pipeline[i].stage <= EMPTY;
                    end
                endcase
            end

            for (int i = MAX_INSTR-1; i > 0; i=i-1) begin
                if (pipeline[i].print)
                    pipeline[i].print <= 0;
            end
        end
    end

    // Simulate pipeline execution
    always_ff @(posedge clk) begin
        // Print the pipeline status for each cycle and capture messages
        for (int i = 0; i < num_instr_in_pipeline; i++) begin
            if (pipeline[i].print) begin
                $display("==========================================================");
                $display("| Instruction: %s | Completed At Cycle: %0t |", pipeline[i].instr_full_msg, $time / 10);
                $display("==========================================================");
                
                for (int j = 0; j < 5; j = j+1)
                    if (pipeline[i].fetch_msgs[j] !== "")
                        $display("%s", pipeline[i].fetch_msgs[j]);
               
                for (int j = 0; j < 5; j = j+1)
                    if (pipeline[i].decode_msgs[j] !== "")
                        $display("%s", pipeline[i].decode_msgs[j]);

                $display("%s", pipeline[i].execute_msg);
                $display("%s", pipeline[i].memory_msg);
                $display("%s", pipeline[i].wb_msg);
                $display("==========================================================\n");
            end
        end
    end

always @(posedge clk) begin
  if (rst) begin
    IF_flush <= 1'b0;
    expected_IF_flush <= 1'b0;
  end else begin
    IF_flush <= iDUT.IF_flush;
    expected_IF_flush <= iMODEL.IF_flush;
  end
end

always @(posedge clk) begin
  if (rst) begin
    load_to_use_hazard <= 1'b0;
    B_hazard <= 1'b0;
    BR_hazard <= 1'b0;
  end else begin
    load_to_use_hazard <= iDUT.iHDU.load_to_use_hazard;
    B_hazard <= iDUT.iHDU.B_hazard;
    BR_hazard <= iDUT.iHDU.BR_hazard;
  end
end


always @(posedge clk) begin
  if (rst) begin
    ID_flush <= 1'b0;
    expected_ID_flush <= 1'b0;
  end else begin
    ID_flush <= iDUT.ID_flush;
    expected_ID_flush <= iMODEL.ID_flush;
  end
end

  // Wrapper task for verifying the FETCH stage
  task verify_fetch;
      output string fetch_msg;
      output string stall_msg;
      // Local variables for capturing the messages from verify_FETCH
      string ftch_msg_local, fetch_stall_msg_local, ftch_flush_msg, fetch_flush_msg;
  begin
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
            .stage_msg(ftch_msg_local),
            .stall_msg(fetch_stall_msg_local)
        );
      
      fetch_msg = {"|", ftch_msg_local, " @ Cycle: ", $sformatf("%0d", ($time/10))};
      stall_msg = {"|", fetch_stall_msg_local, " @ Cycle: ", $sformatf("%0d", ($time/10))};
  end
  endtask

  // Wrapper task for verifying the DECODE stage
  task verify_decode;
      output string decode_msg;
      output string stall_msg;
      output string instr_full_msg;
      // Local variables for capturing messages from verify_DECODE
      string dcode_msg_local, dcode_stall_msg_local, inst_flush_msg;
  begin
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
          .decode_msg(dcode_msg_local), .stall_msg(dcode_stall_msg_local), 
          .instruction_full(instr_full_msg), .instr_flush_msg(inst_flush_msg)
      );
      
      decode_msg = {"|", dcode_msg_local, " @ Cycle: ", $sformatf("%0d", ($time/10))};
      stall_msg = {"|", dcode_stall_msg_local, " @ Cycle: ", $sformatf("%0d", ($time/10))};
  end
  endtask

  // Wrapper task for verifying the EXECUTE stage
  task verify_execute;
      output string execute_msg;
      output string ex_flush_msg;
      // Local variables for capturing messages from verify_EXECUTE
      string ex_msg_local, ex_flush_msg_local;
  begin
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
          
          .execute_msg(ex_msg_local), .ex_flush_msg(ex_flush_msg_local)
      );
      
      execute_msg = {"|", ex_msg_local, " @ Cycle: ", $sformatf("%0d", ($time/10))};
      ex_flush_msg = {"|", ex_flush_msg_local, " @ Cycle: ", $sformatf("%0d", ($time/10))};
  end
  endtask

  // Wrapper task for verifying the MEMORY stage
  task verify_memory;
      output string memory_msg;
      // Local variables for capturing messages from verify_MEMORY
      string mem_verify_msg;
  begin
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
      
      memory_msg = {"|", mem_verify_msg, " @ Cycle: ", $sformatf("%0d", ($time/10))};
  end
  endtask

  // Wrapper task for verifying the WRITEBACK stage
  task verify_writeback;
      output string wb_msg;
      // Local variables for capturing messages from verify_WRITEBACK
      string wb_msg_local;
  begin
      verify_WRITEBACK(
          .MEM_WB_DstReg(iDUT.MEM_WB_reg_rd),
          .MEM_WB_RegWrite(iDUT.MEM_WB_RegWrite),
          .RegWriteData(iDUT.RegWriteData),
          .expected_RegWriteData(iMODEL.RegWriteData),
          
          .wb_verify_msg(wb_msg_local)
      );
      
      wb_msg = {"|", wb_msg_local, " @ Cycle: ", $sformatf("%0d", ($time/10))};
  end
  endtask



  // Generate clock signal with 10 ns period
  always 
    #5 clk = ~clk;

endmodule