`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////////
// ForwardingUnit.v: Forwarding Unit for Hazard Detection    //
//                                                           //
// This module implements the forwarding unit of the         //
// pipeline. It determines whether forwarding should occur   //
// from MEM or WB stages based on the source and destination //
// registers of the EX and MEM stages. The forwarding logic  //
// prevents hazards by ensuring the correct values are used  //
// in the EX stage.                                          //
///////////////////////////////////////////////////////////////
module ForwardingUnit (
    input wire [3:0] ID_EX_SrcReg1, // Pipelined first source register ID from the decode stage
    input wire [3:0] ID_EX_SrcReg2, // Pipelined second source register ID from the decode stage
    input wire [3:0] EX_MEM_reg_rd, // Pipelined register ID of the destination register from the execute stage
    input wire [3:0] MEM_WB_reg_rd, // Pipelined register ID of the destination register from the write-back stage
    input wire EX_MEM_RegWrite,     // Pipelined write enable to the register file from the execute stage
    input wire MEM_WB_RegWrite,     // Pipelined write enable to the register file from the write-back stage

    output wire [1:0] ForwardA,     // Forwarding signal for the first ALU input (ALU_In1)
    output wire [1:0] ForwardB,     // Forwarding signal for the second ALU input (ALU_In2)
    output wire ForwardMEM          // Forwarding signal for MEM stage to MEM stage
);

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire EX_to_EX_haz_A;  // Detects a hazard between the begining and end of the EX stage for the first ALU input
  wire EX_to_EX_haz_B;  // Detects a hazard between the begining and end of the EX stage for the second ALU input
  wire MEM_to_EX_haz_A; // Detects a hazard between the begining of the MEM and EX stage for the first ALU input
  wire MEM_to_EX_haz_B; // Detects a hazard between the begining of the MEM and EX stage for the second ALU input
  wire MEM_to_MEM_haz;  // Detects a hazard between the begining and end of the MEM stage for the SW/LW instruction
  ////////////////////////////////////////////////

  ///////////////////////////////////
  // Set the forwarding conditions //
  ///////////////////////////////////
  // Set the correct signals to enable/disable EX-to-EX/MEM-to-EX forwarding as applicable for the first input operand.
  assign ForwardA = (EX_to_EX_haz_A)  ? 2'b10 :
                    (MEM_to_EX_haz_A) ? 2'b01 :
                    2'b00;
  
  // Set the correct signals to enable/disable EX-to-EX/MEM-to-EX forwarding as applicable for the first input operand.
  assign ForwardB = (EX_to_EX_haz_B)  ? 2'b10 :
                    (MEM_to_EX_haz_B) ? 2'b01 :
                    2'b00;
  
  // Set the correct signals to enable/disable MEM-to-MEM forwarding
  assign ForwardMEM = MEM_to_MEM_haz;
  ////////////////////////////////////

  /////////////////////////////
  // Determine EX-EX haxard  //
  /////////////////////////////
  // The first ALU input has an EX-to-EX hazard when the EX stage is trying to use the value in SrcReg1 (not $0) which 
  // is being written to by the instruction at the begining of the MEM stage.
  assign EX_to_EX_haz_A = (EX_MEM_RegWrite & (EX_MEM_reg_rd != 4'h0)) & (EX_MEM_reg_rd == ID_EX_SrcReg1);

  // The second ALU input has an EX-to-EX hazard when the EX stage is trying to use the value in SrcReg2 (not $0) which 
  // is being written to by the instruction at the begining of the MEM stage.
  assign EX_to_EX_haz_B = (EX_MEM_RegWrite & (EX_MEM_reg_rd != 4'h0)) & (EX_MEM_reg_rd == ID_EX_SrcReg2);
  //////////////////////////////

  //////////////////////////////
  // Determine MEM-EX haxard  //
  //////////////////////////////
  // The first ALU input has an MEM-to-EX hazard when the EX stage is trying to use the value in SrcReg1 (not $0) which 
  // is being written to by the instruction at the begining of the WB stage. We disable this forwarding when
  // there is an EX-to-EX hazard on the same register as MEM-to-EX, in which case we forward the latest result.
  assign MEM_to_EX_haz_A = (MEM_WB_RegWrite & (MEM_WB_reg_rd != 4'h0)) & ~(EX_to_EX_haz_A) & (MEM_WB_reg_rd == ID_EX_SrcReg1);

  // The second ALU input has an MEM-to-EX hazard when the EX stage is trying to use the value in SrcReg2 (not $0) which 
  // is being written to by the instruction at the begining of the WB stage. We disable this forwarding when
  // there is an EX-to-EX hazard on the same register as MEM-to-EX, in which case we forward the latest result.
  assign MEM_to_EX_haz_B = (MEM_WB_RegWrite & (MEM_WB_reg_rd != 4'h0)) & ~(EX_to_EX_haz_B) & (MEM_WB_reg_rd == ID_EX_SrcReg2);
  //////////////////////////////

  ///////////////////////////////
  // Determine MEM-MEM haxard  //
  ///////////////////////////////
  // We detect a MEM-to-MEM hazard when the instruction in the begining of the MEM stage is reading from a register (not $0) 
  // which is being written to by an instruction at the begining of the WB stage.
  assign MEM_to_MEM_haz = (MEM_WB_RegWrite & (MEM_WB_reg_rd != 4'h0)) & (MEM_WB_reg_rd == EX_MEM_reg_rd);
  //////////////////////////////
                  
endmodule

`default_nettype wire // Reset default behavior at the end