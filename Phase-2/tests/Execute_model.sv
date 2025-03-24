/////////////////////////////////////////////////////////////
// Execute_model.sv: Model Instruction Execute Stage       //
//                                                         //
// This module implements the execution stage of the       //
// pipeline for the model CPU.                             //
/////////////////////////////////////////////////////////////
module Execute_model (
    input logic clk,                   // System clock
    input logic rst,                   // Active high synchronous reset
    input logic [15:0] EX_MEM_ALU_in,  // Pipelined ALU result computed from the memory stage
    input logic [15:0] MEM_WB_ALU_in,  // Pipelined ALU/data memory result computed from the WB stage
    input logic [15:0] ALU_In1_step,   // First input to ALU (from the decode stage)
    input logic [15:0] ALU_imm,        // Immediate for I-type ALU instructions (from the decode stage)
    input logic [15:0] ALU_In2_step,   // Second ALU input based on the instruction type (from the decode stage)
    input logic [1:0] ForwardA,        // Forwarding signal for the first ALU input (ALU_In1)
    input logic [1:0] ForwardB,        // Forwarding signal for the second ALU input (ALU_In2)
    input logic [3:0] ALUOp,           // ALU operation code (from the decode stage)
    input logic ALUSrc,                // Selects second ALU input (immediate or SrcReg2_data) based on instruction type (from the decode stage)
    input logic Z_en,                  // Enable signal for Z flag
    input logic NV_en,                 // Enable signal for N and V flags
    
    output logic ZF,                   // Zero flag output
    output logic NF,                   // Negative flag output
    output logic VF,                   // Overflow flag output
    output logic [15:0] ALU_out        // ALU operation result output
);

  ////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ////////////////////////////////////////////////
  logic [15:0] ALU_In1;       // First input to ALU
  logic [15:0] ALU_In2_stg;   // Second ALU input choice from the current value or forwarded result.
  logic [15:0] ALU_In2;       // Second ALU input based on the instruction type
  logic Z_set, V_set, N_set;  // Flags set signals by the ALU
  ////////////////////////////////////////////////

  /////////////////////////////////////////////
  // EXECUTE instruction based on the opcode //
  /////////////////////////////////////////////
  // First ALU input either take the forwarded result or the current instruction's decoded values.
  assign ALU_In1 = (ForwardA == 2'b10) ? EX_MEM_ALU_in :
                   (ForwardA == 2'b01) ? MEM_WB_ALU_in :
                   ALU_In1_step;
  
  // Second ALU input either take the forwarded result or the current instruction's decoded values.
  assign ALU_In2_stg = (ForwardB == 2'b10) ? EX_MEM_ALU_in :
                       (ForwardB == 2'b01) ? MEM_WB_ALU_in :
                       ALU_In2_step;

  // Determine the 2nd ALU input, either immediate or ALU_In2_stg if non I-type instruction.
  assign ALU_In2 = (ALUSrc) ? ALU_imm : ALU_In2_stg;

  // Execute the instruction on the ALU based on the opcode.
  ALU_model iALU_model (.ALU_In1(ALU_In1),
                        .ALU_In2(ALU_In2),
                        .Opcode(ALUOp),
                        
                        .ALU_Out(ALU_out),
                        .Z_set(Z_set),
                        .N_set(N_set),
                        .V_set(V_set)
                        );
  /////////////////////////////////////////////

  ////////////////////////////////////////////////////
  // Set FLAGS based on the output of the execution //
  ////////////////////////////////////////////////////
  always @(posedge clk)
    if (rst)
      ZF <= 1'b0;
    else if (Z_en)
        ZF <= Z_set;
  
  always @(posedge clk)
    if (rst)
      VF <= 1'b0;
    else if (NV_en)
      VF <= V_set;

  always @(posedge clk)
    if (rst)
      NF <= 1'b0;
    else if (NV_en)
      NF <= N_set;
  ////////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end