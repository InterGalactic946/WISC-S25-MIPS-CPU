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

  ///////////////////////////////////////////
  // Declare any internal signals as wire  //
  ///////////////////////////////////////////
  wire [3:0] addr; // Used to determine read vs write address.
  ///////////////////////////////////////////

  //////////////////////////////////////////////////
  // Implement BTB as structural/dataflow verilog //
  //////////////////////////////////////////////////
  // Our read address is PC_curr while our write address is IF_ID_PC_curr.
  assign addr = (wen) ? IF_ID_PC_curr : PC_curr;

  // Infer the branch target buffer as an asynchronously read, synchronously written memory, enabled when not stalling.
  memory1c #(4) iMEM_BTB (.data_out(predicted_target),
                          .data_in(actual_target),
                          .addr(addr),
                          .enable(enable),
                          .data(1'b1),
                          .wr(wen),
                          .clk(clk),
                          .rst(rst)
                          );
endmodule

`default_nettype wire // Reset default behavior at the end
