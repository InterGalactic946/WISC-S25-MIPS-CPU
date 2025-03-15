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
    input wire clk,                // System clock
    input wire rst,                // Active high synchronous reset
    input wire [15:0] ALU_In1,     // First input to ALU (from the decode stage)
    input wire [15:0] ALU_In2,     // Second input to ALU (from the decode stage)
    input wire [3:0] ALU_Op,       // ALU operation code (from the decode stage)
    input wire Z_en,               // Enable signal for Z flag
    input wire NV_en,              // Enable signal for N and V flags
    
    output wire ZF,                // Zero flag output
    output wire NF,                // Negative flag output
    output wire VF,                // Overflow flag output
    output wire [15:0] ALU_out     // ALU operation result output
);

  ////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ////////////////////////////////////////////////
  wire Z_set, V_set, N_set;  // Flags set signals by the ALU
  ////////////////////////////////////////////////

  /////////////////////////////////////////////
  // EXECUTE instruction based on the opcode //
  /////////////////////////////////////////////
  ALU iALU (.ALU_In1(ALU_In1),
            .ALU_In2(ALU_In2),
            .Opcode(ALUOp),
            .ALU_Out(ALU_out),
            .Z_set(Z_set),
            .N_set(N_set),
            .V_set(V_set)
          );

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

endmodule

`default_nettype wire // Reset default behavior at the end