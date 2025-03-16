`default_nettype none // Set the default as none to avoid errors

/////////////////////////////////////////////////////////////
// Execute.v: Instruction Execute Stage                    //
//                                                         //
// This module implements the execution stage of the       //
// pipeline. It performs arithmetic and logical operations //
// based on the input ALU operation code and inputs.       //
// It also generates the Zero (Z), Negative (N), and       //
// Overflow (V) flags based on the ALU output.             //
/////////////////////////////////////////////////////////////
module Execute(
    input wire clk,                   // System clock
    input wire rst,                   // Active high synchronous reset
    input wire [15:0] EX_MEM_ALU_in,  // Pipelined ALU result computed from the memory stage
    input wire [15:0] MEM_WB_ALU_in,  // Pipelined ALU/data memory result computed from the WB stage
    input wire [15:0] ALU_In1_step,   // First input to ALU (from the decode stage)
    input wire [15:0] ALU_imm,        // Immediate for I-type ALU instructions (from the decode stage)
    input wire [15:0] ALU_In2_step,   // Second ALU input based on the instruction type (from the decode stage)
    input wire [1:0] ForwardA,        // Forwarding signal for the first ALU input (ALU_In1)
    input wire [1:0] ForwardB,        // Forwarding signal for the second ALU input (ALU_In2)
    input wire [3:0] ALUOp,           // ALU operation code (from the decode stage)
    input wire ALUSrc,                // Selects second ALU input (immediate or SrcReg2_data) based on instruction type (from the decode stage)
    input wire Z_en,                  // Enable signal for Z flag
    input wire NV_en,                 // Enable signal for N and V flags
    
    output wire ZF,                   // Zero flag output
    output wire NF,                   // Negative flag output
    output wire VF,                   // Overflow flag output
    output wire [15:0] ALU_out        // ALU operation result output
);

  ////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ////////////////////////////////////////////////
  wire [15:0] ALU_In1;       // First input to ALU
  wire [15:0] ALU_In2_stg;   // Second ALU input choice from the current value or forwarded result.
  wire [15:0] ALU_In2;       // Second ALU input based on the instruction type
  wire Z_set, V_set, N_set;  // Flags set signals by the ALU
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
  ALU iALU (.ALU_In1(ALU_In1),
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
  Flag_Register iFR (
    .clk(clk),
    .rst(rst),
    .wen({Z_en, NV_en, NV_en}),
    .flags_in({Z_set, V_set, N_set}),
    .flags_out({ZF, VF, NF})
  );
  ////////////////////////////////////////////////////

endmodule

`default_nettype wire // Reset default behavior at the end