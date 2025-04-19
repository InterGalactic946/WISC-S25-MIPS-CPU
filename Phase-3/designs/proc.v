`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////////
// proc.v: Processor Core Module                          //
//                                                        //
// This module implements the CPU core that interfaces    //
// with external memory using a simple handshake protocol.//
// It is responsible for fetching, decoding, executing    //
// instructions, and managing caches and registers.       //
////////////////////////////////////////////////////////////
module proc (
  input  wire        clk,               // System clock
  input  wire        rst,               // Active high synchronous reset

  // Memory interface
  input  wire        mem_data_valid,    // Indicates valid data on read
  input  wire [15:0] mem_data_in,       // Data read from memory

  output wire        mem_en,            // Memory enable signal
  output wire [15:0] mem_addr,          // Address to read/write
  output wire        mem_wr,            // Memory write enable
  output wire [15:0] mem_data_out,      // Data to be written to memory

  // Top-level outputs
  output wire        hlt,               // Processor halt signal
  output wire [15:0] pc                 // Current program counter
);

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  /*ARBITRATOR SIGNALS */
  wire ICACHE_proceed;          // Signal to proceed with data memory access on an ICACHE miss
  wire DCACHE_proceed;          // Signal to proceed with data memory access on an DCACHE miss
  wire mem_en_miss;             // Enables main memory on a cache miss
  
  /* FETCH stage signals */
  wire [15:0] PC_next;          // Next PC address
  wire [1:0] prediction;        // 2-bit Prediction from the branch history table
  wire [15:0] predicted_target; // Predicted target address of the branch instruction

  /* ICACHE signals */
  wire [15:0] PC_inst;          // Instruction fetched from memory at the current PC address
  wire hlt_fetched;             // Indicates if the fetched instruction is a halt instruction.
  wire [15:0] I_MEM_addr;       // The address to access in off chip memory on an ICACHE miss
  wire ICACHE_busy;             // Indicates ICACHE FSM is currently busy processing
  wire ICACHE_hit;              // Indicates a cache hit for the current PC access

  /* IF/ID Pipeline Register signals */
  wire [15:0] IF_ID_PC_curr;            // Current PC value pipelined from the Fetch stage
  wire [15:0] IF_ID_PC_next;            // Next PC value pipelined from the Fetch stage
  wire [15:0] IF_ID_PC_inst;            // Instruction word pipelined from the Fetch stage
  wire [1:0]  IF_ID_prediction;         // Branch prediction outcome pipelined from the Fetch stage
  wire [15:0] IF_ID_predicted_target;   // Predicted branch target address pipelined from the Fetch stage

  /* DECODE stage signals */
  wire Branch;               // Indicates it is a branch instruction
  wire BR;                   // Indicates it is a branch register instruction
  wire actual_taken;         // Signal used to determine whether an instruction met condition codes
  wire wen_BHT;              // Write enable for BHT (Branch History Table)
  wire [15:0] branch_target; // Computed branch target address
  wire wen_BTB;              // Write enable for BTB (Branch Target Buffer)
  wire [15:0] actual_target; // Computed actual target address
  wire update_PC;            // Signal to update the PC with the actual target
  wire [62:0] EX_signals;    // Execute stage control signals
  wire [17:0] MEM_signals;   // Memory stage control signals
  wire [7:0] WB_signals;     // Write-back stage control signals

  /* HAZARD DETECTION UNIT signals */
  wire PC_stall;                        // Stall signal for the PC register
  wire IF_ID_stall;                     // Stall signal for the IF/ID pipeline register
  wire ID_EX_stall;                     // Stall signal for the ID/EX pipeline register
  wire EX_MEM_stall;                    // Stall signal for the EX/MEM pipeline register
  wire IF_flush, ID_flush, MEM_flush;   // Flush signals for each pipeline register

  /* ID/EX Pipeline Register signals */
  wire [3:0] ID_EX_SrcReg1;        // Pipelined first source register ID from the decode stage
  wire [3:0] ID_EX_SrcReg2;        // Pipelined second source register ID from the decode stage
  wire [15:0] ID_EX_ALU_In1;       // Pipelined first ALU input from the decode stage
  wire [15:0] ID_EX_ALU_imm;       // Pipelined ALU immediate input from the decode stage
  wire [15:0] ID_EX_ALU_In2;       // Pipelined second ALU input from the decode stage
  wire [3:0] ID_EX_ALUOp;          // Pipelined ALU operation code from the decode stage
  wire ID_EX_ALUSrc;               // Pipelined ALU select signal to choose between register/immediate operand from the decode stage
  wire ID_EX_Z_en, ID_EX_NV_en;    // Pipelined enable signals setting the Z, N, and V flags from the decode stage
  wire [15:0] ID_EX_MemWriteData;  // Pipelined write data for SW from the decode stage or forwarded data from the WB stage
  wire [17:0] ID_EX_MEM_signals;   // Pipelined Memory stage control signals from the decode stage
  wire [7:0] ID_EX_WB_signals;     // Pipelined Write-back stage control signals from the decode stage
  wire [15:0] ID_EX_PC_next;       // Pipelined next instruction (previous PC_next) address from the fetch stage

  /* EXECUTE stage signals */
  wire [15:0] ALU_out;             // ALU output
  wire ZF, VF, NF;                 // Flag signals

  /* FORWARDING UNIT signals */
  wire [1:0] ForwardA;              // Forwarding signal for the first ALU input (ALU_In1)
  wire [1:0] ForwardB;              // Forwarding signal for the second ALU input (ALU_In2)
  wire ForwardSW_EX;                // Forwarding signal for the SW instruction in the EX stage
  wire ForwardSW_MEM;               // Forwarding signal for the SW instruction in the MEM stage

  /* EX/MEM Pipeline Register signals */
  wire [15:0] EX_MEM_ALU_out;      // Pipelined data memory address/arithemtic computation result computed from the execute stage
  wire [3:0] EX_MEM_SrcReg2;       // Pipelined second source register ID from the decode stage
  wire [15:0] EX_MEM_MemWriteData; // Pipelined write data for SW from the decode stage
  wire EX_MEM_MemEnable;           // Pipelined data memory access enable signal from the decode stage
  wire EX_MEM_MemWrite;            // Pipelined data memory write enable signal from the decode stage
  wire [7:0] EX_MEM_WB_signals;    // Pipelined Write-back stage control signals from the decode stage
  wire [15:0] EX_MEM_PC_next;      // Pipelined next instruction (previous PC_next) address from the fetch stage

  /* MEMORY stage signals */
  wire [15:0] MemWriteData;        // Data written to memory
  wire [15:0] D_MEM_addr;          // The address to access in off chip memory on an DCACHE miss
  wire DCACHE_busy;                // Indicates the DCACHE FSM is busy processing
  wire [15:0] MemData;             // Data read from memory
  wire DCACHE_hit;                 // Indicates if current memory access was a cache hit

  /* MEM/WB Pipeline Register signals */
  wire [15:0] MEM_WB_MemData; // Pipelined data read from memory from the memory stage
  wire [15:0] MEM_WB_ALU_out; // Pipelined arithemtic computation result computed from the execute stage
  wire MEM_WB_MemEnable;      // Previous cycle's memory enable (for FSM bookkeeping)
  wire MEM_WB_first_tag_LRU;  // Previous cycle's LRU result on the first "way"
  wire MEM_WB_first_match;    // Previous cycle's tag match result on the first "way"
  wire MEM_WB_DCACHE_hit;     // Previous cycle's cache hit signal
  wire [3:0] MEM_WB_reg_rd;   // Pipelined register ID of the destination register from the decode stage
  wire MEM_WB_RegWrite;       // Pipelined write enable to the register file from the decode stage
  wire MEM_WB_MemToReg;       // Pipelined select signal to write data read from memory or ALU result back to the register file
  wire MEM_WB_HLT;            // Pipelined HLT signal from the decode stage (indicates that the HLT instruction, if fetched, entered the WB stage) 
  wire MEM_WB_PCS;            // Pipelined PCS signal from the decode stage (indicates that the PCS instruction, if fetched, entered the WB stage)
  wire [15:0] MEM_WB_PC_next; // Pipelined next instruction (previous PC_next) address from the fetch stage

  /* WRITE_BACK stage signals */
  wire [15:0] RegWriteData;   // Data to write back to the register file
  //////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////
  // Raise the hlt signal when the HLT instruction is encountered //
  //////////////////////////////////////////////////////////////////
  // Halts the processor if a HLT instruction is encountered and is in the WB stage.
  assign hlt = MEM_WB_HLT;

  //////////////////////////////////////////////////////////
  // Arbitrate accesses to data memory between I/D caches //
  //////////////////////////////////////////////////////////
  Cache_Arbiter iARBITER (
    .clk(clk),        
    .rst(rst),         
    .ICACHE_busy(ICACHE_busy),   
    .DCACHE_busy(DCACHE_busy),   
    
    .mem_en(mem_en_miss),
    .i_grant(ICACHE_proceed),
    .d_grant(DCACHE_proceed)        
  );

  // We send out the main memory address as from the instruction cache or data cache based on which is granted.
  assign mem_addr = (ICACHE_proceed) ? I_MEM_addr :
                    (DCACHE_proceed) ? D_MEM_addr :
                    16'h0000;

  // We enable main memory either on a cache miss or on a DCACHE write.
  assign mem_en = mem_en_miss | (DCACHE_hit & EX_MEM_MemWrite & EX_MEM_MemEnable);

  // We write to main memory on a DCACHE write hit as it is a write through cache.
  assign mem_wr = (DCACHE_hit & EX_MEM_MemWrite & EX_MEM_MemEnable);
  /////////////////////////////////////////////////////////////

  ////////////////////////////////
  // FETCH instruction from PC  //
  ////////////////////////////////
  Fetch iFETCH (
    .clk(clk), 
    .rst(rst), 
    .stall(PC_stall), 
    .hlt_fetched(hlt_fetched),
    .actual_taken(actual_taken),
    .wen_BHT(wen_BHT),
    .branch_target(branch_target),
    .wen_BTB(wen_BTB),
    .actual_target(actual_target),
    .update_PC(update_PC),
    .IF_ID_PC_curr(IF_ID_PC_curr),
    .IF_ID_prediction(IF_ID_prediction), 
      
    .PC_next(PC_next), 
    .PC_curr(pc),
    .prediction(prediction),
    .predicted_target(predicted_target)
  );
  ///////////////////////////////////

  ////////////////////////////////////////
  // Instantiate instruction memory cache along with control.
  memory_system iINSTR_MEM_CACHE (
      .clk(clk),
      .rst(rst),
      .enable(1'b1),
      .proceed(ICACHE_proceed),
      .on_chip_wr(1'b0),
      .on_chip_memory_address(pc),
      .on_chip_memory_data(16'h0000),

      .off_chip_memory_data(mem_data_in),
      .memory_data_valid(mem_data_valid),

      .off_chip_memory_address(I_MEM_addr),
      
      .fsm_busy(ICACHE_busy),

      .data_out(PC_inst),
      .hit(ICACHE_hit)
  );

  // Get the condition that we fetched a halt instruction.
  assign hlt_fetched = &PC_inst[15:12];
  //////////////////////////////////////////

  /////////////////////////////////////////////////
  // Pass the instruction word, current PC, prediction & target, and the next PC address to the IF/ID pipeline register.
  IF_ID_pipe_reg iIF_ID (
    .clk(clk),
    .rst(rst),
    .stall(IF_ID_stall),
    .flush(IF_flush),
    .PC_curr(pc),
    .PC_next(PC_next),
    .PC_inst(PC_inst),
    .prediction(prediction),
    .predicted_target(predicted_target),
    
    .IF_ID_PC_curr(IF_ID_PC_curr), 
    .IF_ID_PC_next(IF_ID_PC_next),
    .IF_ID_PC_inst(IF_ID_PC_inst),
    .IF_ID_prediction(IF_ID_prediction),
    .IF_ID_predicted_target(IF_ID_predicted_target)
  );
  /////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////
  // DECODE instruction word, resolve branches, and access register file   //
  ///////////////////////////////////////////////////////////////////////////
  Decode iDECODE (
    .clk(clk),
    .rst(rst),
    .pc_curr(pc),
    .pc_inst(IF_ID_PC_inst),
    .pc_next(IF_ID_PC_next),
    .flags({ZF, VF, NF}), 
    .IF_ID_predicted_target(IF_ID_predicted_target),
    .MEM_WB_RegWrite(MEM_WB_RegWrite),
    .MEM_WB_reg_rd(MEM_WB_reg_rd),
    .RegWriteData(RegWriteData),
    
    .EX_signals(EX_signals),
    .MEM_signals(MEM_signals),
    .WB_signals(WB_signals),

    .is_branch(Branch),
    .is_BR(BR),
    .actual_taken(actual_taken),
    .wen_BHT(wen_BHT),
    .branch_target(branch_target),
    .wen_BTB(wen_BTB),
    .actual_target(actual_target),
    .update_PC(update_PC)
  );
  ///////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////
  // Instantiate the Hazard Detection Unit  //
  ////////////////////////////////////////////
  // ID_EX_WB_signals[7:4] == ID_EX_reg_rd, ID_EX_WB_signals[3] == ID_EX_RegWrite.
  // EX_MEM_WB_signals[7:4] == EX_MEM_reg_rd, EX_MEM_WB_signals[3] == EX_MEM_RegWrite.
  // ID_EX_MEM_signals[1] == ID_EX_MemEnable, ID_EX_MEM_signals[0] == ID_EX_MemWrite.
  // MEM_signals[1] == MemEnable.
  // EX_signals[62:59] == SrcReg1, EX_signals[58:55] == SrcReg2. 
  HazardDetectionUnit iHDU (
      .SrcReg1(EX_signals[62:59]),
      .SrcReg2(EX_signals[58:55]),
      .ID_EX_RegWrite(ID_EX_WB_signals[3]),
      .ID_EX_reg_rd(ID_EX_WB_signals[7:4]),
      .EX_MEM_reg_rd(EX_MEM_WB_signals[7:4]),
      .EX_MEM_RegWrite(EX_MEM_WB_signals[3]),
      .ID_EX_MemEnable(ID_EX_MEM_signals[1]),
      .ID_EX_MemWrite(ID_EX_MEM_signals[0]),
      .MemWrite(MEM_signals[1]),
      .ID_EX_Z_en(ID_EX_Z_en),
      .ID_EX_NV_en(ID_EX_NV_en),
      .Branch(Branch),
      .BR(BR),
      .ICACHE_busy(ICACHE_busy),
      .DCACHE_busy(DCACHE_busy),
      .update_PC(update_PC),
      
      .PC_stall(PC_stall),
      .IF_ID_stall(IF_ID_stall),
      .ID_EX_stall(ID_EX_stall),
      .EX_MEM_stall(EX_MEM_stall),
      .MEM_flush(MEM_flush),
      .ID_flush(ID_flush),
      .IF_flush(IF_flush)
  );
  ///////////////////////////////////////////////

  /////////////////////////////////////////////////
  // Pass the next PC, instruction word's control signals and operands to the ID/EX pipeline register.
  ID_EX_pipe_reg iID_EX (
      .clk(clk),
      .rst(rst),
      .stall(ID_EX_stall),
      .flush(ID_flush),
      .IF_ID_PC_next(IF_ID_PC_next),
      .EX_signals(EX_signals),
      .MEM_signals(MEM_signals),
      .WB_signals(WB_signals),
      
      .ID_EX_PC_next(ID_EX_PC_next),
      .ID_EX_EX_signals({ID_EX_SrcReg1, ID_EX_SrcReg2,
      ID_EX_ALU_In1, ID_EX_ALU_imm, ID_EX_ALU_In2, 
      ID_EX_ALUOp, ID_EX_ALUSrc, ID_EX_Z_en, ID_EX_NV_en}),
      .ID_EX_MEM_signals(ID_EX_MEM_signals),
      .ID_EX_WB_signals(ID_EX_WB_signals)
  );
  /////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////
  // EXECUTE instruction and set flags based on the opcode //
  ///////////////////////////////////////////////////////////
  Execute iEXECUTE (
      .clk(clk),
      .rst(rst),
      .EX_MEM_ALU_in(EX_MEM_ALU_out),
      .MEM_WB_ALU_in(RegWriteData),
      .ALU_In1_step(ID_EX_ALU_In1),
      .ALU_imm(ID_EX_ALU_imm),
      .ALU_In2_step(ID_EX_ALU_In2),
      .ForwardA(ForwardA),
      .ForwardB(ForwardB),
      .ALUOp(ID_EX_ALUOp),
      .ALUSrc(ID_EX_ALUSrc),
      .Z_en(ID_EX_Z_en),
      .NV_en(ID_EX_NV_en),
      
      .ZF(ZF),
      .NF(NF),
      .VF(VF),
      .ALU_out(ALU_out)
  );
  ////////////////////////////////////////////////////////////

  //////////////////////////////////////
  // Instantiate the Forwarding Unit  //
  //////////////////////////////////////
  // EX_MEM_WB_signals[7:4] == EX_MEM_reg_rd, EX_MEM_WB_signals[3] == EX_MEM_RegWrite.
  ForwardingUnit iFWD (
    .ID_EX_SrcReg1(ID_EX_SrcReg1),
    .ID_EX_SrcReg2(ID_EX_SrcReg2),
    .EX_MEM_SrcReg2(EX_MEM_SrcReg2),
    .EX_MEM_reg_rd(EX_MEM_WB_signals[7:4]),
    .MEM_WB_reg_rd(MEM_WB_reg_rd),
    .EX_MEM_RegWrite(EX_MEM_WB_signals[3]),
    .MEM_WB_RegWrite(MEM_WB_RegWrite),
    
    .ForwardA(ForwardA),
    .ForwardB(ForwardB),
    .ForwardSW_EX(ForwardSW_EX),
    .ForwardSW_MEM(ForwardSW_MEM)
  );
  ///////////////////////////////////////

  // Decide to pipeline the memory write data from decode or the forwarded data from the write-back stage.
  assign ID_EX_MemWriteData = (ForwardSW_EX) ? RegWriteData : ID_EX_MEM_signals[17:2];

  /////////////////////////////////////////////////
  // Pass the next PC, ALU output along with control signals to the EX/MEM pipeline register. 
  EX_MEM_pipe_reg iEX_MEM (
      .clk(clk),
      .rst(rst),
      .stall(EX_MEM_stall),
      .ID_EX_PC_next(ID_EX_PC_next),
      .ALU_out(ALU_out),
      .ID_EX_SrcReg2(ID_EX_SrcReg2),
      .ID_EX_MEM_signals({ID_EX_MemWriteData, ID_EX_MEM_signals[1:0]}),
      .ID_EX_WB_signals(ID_EX_WB_signals),
      
      .EX_MEM_PC_next(EX_MEM_PC_next),
      .EX_MEM_ALU_out(EX_MEM_ALU_out),
      .EX_MEM_SrcReg2(EX_MEM_SrcReg2),
      .EX_MEM_MEM_signals({EX_MEM_MemWriteData, EX_MEM_MemEnable, EX_MEM_MemWrite}),
      .EX_MEM_WB_signals(EX_MEM_WB_signals)
  );
  /////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////
  // Data MEMORY Access (read/write data for LW/SW as applicable) //
  //////////////////////////////////////////////////////////////////
  // Use the value read out from data memory from the previous instruction 
  // or previous ALU result if forwarded otherwise the current value. 
  assign MemWriteData = (ForwardSW_MEM) ? RegWriteData : EX_MEM_MemWriteData;

  // Instantiate data memory cache along with control.
  memory_system iDATA_MEM_CACHE (
      .clk(clk),
      .rst(rst),
      .enable(EX_MEM_MemEnable),
      .proceed(DCACHE_proceed),
      .on_chip_wr(EX_MEM_MemWrite),
      .on_chip_memory_address(EX_MEM_ALU_out),
      .on_chip_memory_data(MemWriteData),

      .off_chip_memory_data(mem_data_in),
      .memory_data_valid(mem_data_valid),

      .off_chip_memory_address(D_MEM_addr),

      .fsm_busy(DCACHE_busy),
      
      .data_out(MemData),
      .hit(DCACHE_hit)
  );
  //////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////
  // Pass the next PC, data read out from memory and ALU result to the MEM/WB pipeline register.
  MEM_WB_pipe_reg iMEM_WB (
      .clk(clk),
      .rst(rst),
      .flush(MEM_flush),
      .EX_MEM_PC_next(EX_MEM_PC_next),
      .EX_MEM_ALU_out(EX_MEM_ALU_out),
      .EX_MEM_MemEnable(EX_MEM_MemEnable),
      .first_tag_LRU(first_tag_LRU),
      .first_match(first_match),
      .DCACHE_hit(DCACHE_hit),
      .MemData(MemData),
      .EX_MEM_WB_signals(EX_MEM_WB_signals),
      
      .MEM_WB_PC_next(MEM_WB_PC_next),
      .MEM_WB_ALU_out(MEM_WB_ALU_out),
      .MEM_WB_MemEnable(MEM_WB_MemEnable),
      .MEM_WB_first_tag_LRU(MEM_WB_first_tag_LRU),
      .MEM_WB_first_match(MEM_WB_first_match),
      .MEM_WB_DCACHE_hit(MEM_WB_DCACHE_hit),
      .MEM_WB_MemData(MEM_WB_MemData),
      .MEM_WB_WB_signals({MEM_WB_reg_rd, MEM_WB_RegWrite, MEM_WB_MemToReg, MEM_WB_HLT, MEM_WB_PCS})
  );
  /////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////
  // WRITE_BACK data to the register file based on PCS/LW/ALU as applicable //
  ////////////////////////////////////////////////////////////////////////////
  // Grab the data from memory for LW for write back or if it's PCS, we send (PC+2) for write back,
  // otherwise send the ALU output.
  assign RegWriteData = (MEM_WB_MemToReg) ? MEM_WB_MemData : ((MEM_WB_PCS) ? MEM_WB_PC_next : MEM_WB_ALU_out);

endmodule

`default_nettype wire  // Reset default behavior at the end