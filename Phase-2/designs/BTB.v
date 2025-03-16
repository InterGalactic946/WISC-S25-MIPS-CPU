`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////////////
// Branch Target Buffer (BTB): 16-bit Addressing for Target //
//                                                          //
// This design implements a Branch Target Buffer (BTB)      //
// that caches the target addresses of taken branches.      //
// The BTB is indexed using the lower 4 bits of the PC      //
// value, and it stores the corresponding branch targets.   //
//////////////////////////////////////////////////////////////
module BTB (
    input wire clk,                       // System clock
    input wire rst,                       // Active high reset signal
    input wire [3:0] PC_curr_lower,       // 4-bit address (lower 4-bits of current PC from the fetch stage)
    input wire [3:0] IF_ID_PC_curr_lower, // Pipelined 4-bit address (lower 4-bits of previous PC from the fetch stage)
    input wire wen,                       // Write enable signal for updating BTB
    input wire [15:0] actual_target,      // 16-bit actual target address of the branched instruction (from the decode stage)
    output wire [15:0] predicted_target   // Predicted cached target address (16-bit) along with the valid bit (MSB)
);

  ///////////////////////////////////////////
  // Declare any internal signals as wire  //
  ///////////////////////////////////////////
  wire [15:0] WriteWordline   // Select lines for 16 registers (write)
  wire [15:0] ReadWordline;   // Select lines for 16 registers (read)
  wire [15:0] unused_bitline; // Unused bitline read out of the BTB
  ///////////////////////////////////////////

  //////////////////////////////////////////////////
  // Implement BHT as structural/dataflow verilog //
  //////////////////////////////////////////////////
  // Instantiate two read register decoders (for both read and write operations).
  ReadDecoder_4_16 iREAD_DECODER (.RegId(PC_curr_lower), .Wordline(ReadWordline));
  WriteDecoder_4_16 iWRITE_DECODER (.RegId(IF_ID_PC_curr_lower), .WriteReg(wen), .Wordline(WriteWordline));

  // Vector instantiate 16 registers, each 16-bit wide for the BTB.
  Register iRF_BTB [15:0] (.clk({16{clk}}), .rst({16{rst}}), .D(actual_target), .WriteReg(WriteWordline), .ReadEnable1(ReadWordline), .ReadEnable2(ReadWordline), .Bitline1(predicted_target), .Bitline2(unused_bitline));

endmodule

`default_nettype wire // Reset default behavior at the end
