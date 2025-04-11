`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////////
// Branch_Cache.v: WIDTH-bit cache for branch prediction  //
//                                                        //
// This design implements a cache for branch prediction.  //
// It allows reading from two source registers (`SrcReg1` //
// and `SrcReg2`) and writing to a destination register   //
// (`DstReg`). The `WriteReg` signal enables writing      //
// data to the `DstReg`, and `DstData` is the data to be  //
// written.                                               //
////////////////////////////////////////////////////////////
module Branch_Cache(clk, rst, SrcCurr, SrcPrev, DstPrev, wen, DstData, SrcDataCurr, SrcDataPrev);

  parameter WIDTH = 16;                             // Width of the registers in bits.
  
  input wire clk, rst;                              // system clock and active high synchronous reset inputs
  input wire [2:0] SrcCurr;                         // Src reg ID of current branch
  input wire [2:0] SrcPrev;                         // Src reg ID of previous branch
  input wire [2:0] DstPrev;                         // Dest reg ID of previous instruction
  input wire enable;                                // Enable signal for the cache
  input wire wen;                                   // used to enable writing to the cache
  input wire [WIDTH-1:0] DstData;                   // WIDTH-bit data to be written to the destination register
  output wire [WIDTH-1:0] SrcDataCurr, SrcDataPrev; // Read outputs of both source registers

  /////////////////////////////////////////////////
  // Declare any internal signals as type wire  //
  ///////////////////////////////////////////////
  wire data_prev, data_curr;          // Data read out from both registers.
  wire write_enable;                  // Write enable signal for the cache.
  wire [7:0] Wordline_1, Wordline_2;  // Select lines for register 1 and 2.
  wire [7:0] Wordline_dst;            // Select line for destination register.
  //////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////
  // Implement the branch cache as structural/dataflow verilog //
  //////////////////////////////////////////////////////////////
  // Instantiate two read register decoders.
  ReadDecoder_3_8 iREAD_CURR (.RegId(SrcCurr), .Wordline(Wordline_curr));
  ReadDecoder_3_8 iREAD_PREV (.RegId(SrcPrev), .Wordline(Wordline_prev));

  // Cache is only one write enabled if both enable and wen are high.
  assign write_enable = (enable & wen) ? 1'b1 : 1'b0;

  // Instantiate a single write decoder.
  WriteDecoder_3_8 iWRITE (.RegId(DstPrev), .WriteReg(write_enable), .Wordline(Wordline_dst));

  // Vector instantiate 8 registers to track the last 8 branch instructions.
  Register iBRANCH_CACHE[0:7] (.clk({WIDTH{clk}}), .rst({WIDTH{rst}}), .D(DstData), .WriteReg(Wordline_dst), .ReadEnable1(Wordline_curr), .ReadEnable2(Wordline_prev), .Bitline1(data_curr), .Bitline2(data_prev));

  // Read the data from the cache registers.
  assign SrcDataCurr = data_curr;
  assign SrcDataPrev = data_prev;

endmodule

`default_nettype wire // Reset default behavior at the end