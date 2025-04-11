`default_nettype none // Set the default as none to avoid errors

//////////////////////////////////////////////////////////////
// BTB.v: 16-bit Branch Target Buffer                       //
//                                                          //
// This design implements a Branch Target Buffer (BTB)      //
// that caches the target addresses of taken branches.      //
// The BTB is indexed using the lower 4 bits of the PC      //
// value, and it stores the corresponding branch targets.   //
//////////////////////////////////////////////////////////////
module BTB (
    input wire clk,                    // System clock
    input wire rst,                    // Active high reset signal
    input wire [3:0] PC_curr,          // 4-bit address (lower 4-bits of current PC from the fetch stage)
    input wire [3:0] IF_ID_PC_curr,    // Pipelined 4-bit address (lower 4-bits of previous PC from the fetch stage)
    input wire wen,                    // Write enable signal for updating BTB when the branch is actually taken or when miscomputed
    input wire enable,                 // Enable signal for the BTB
    input wire [15:0] actual_target,   // 16-bit actual target address of the branched instruction (from the decode stage)
    
    output wire [15:0] predicted_target // Predicted cached target address (16-bit) along with the valid bit (MSB)
);

  // Infer the branch target buffer as an asynchronously read, synchronously written memory, enabled when not stalling.
  Branch_Cache iMEM_BTB (
              .clk(clk),
              .rst(rst),
              .SrcCurr(PC_curr[3:1]),
              .SrcPrev(IF_ID_PC_curr[3:1]),
              .DstPrev(IF_ID_PC_curr[3:1]),
              .enable(enable),
              .wen(wen),
              .DstData(actual_target),
              .SrcDataCurr(predicted_target),
              .SrcDataPrev()
            );

endmodule

`default_nettype wire // Reset default behavior at the end
