`default_nettype none // Set the default as none to avoid errors

////////////////////////////////////////////////////////////
// Branch_Cache.v: WIDTH-bit cache for branch prediction  //
//                                                        //
// This module implements a small register file-like      //
// structure to support branch prediction mechanisms.     //
// It tracks recently used registers involved in branch   //
// instructions and provides quick access to their data.  //
// The cache supports reading values for two source       //
// registers and conditionally writing new data to a      //
// destination register on each clock cycle.              //
////////////////////////////////////////////////////////////
module Branch_Cache(clk, rst, SrcCurr, SrcPrev, DstPrev, enable, wen, DstData, SrcDataCurr, SrcDataPrev);

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
  wire [WIDTH-1:0] data_prev, data_curr;    // Data read out from both registers.
  wire write_enable;                        // Write enable signal for the cache.
  wire [7:0] Wordline_curr, Wordline_prev;  // Select lines for previous and current registers.
  wire [7:0] Wordline_dst;                  // Select line for destination register.
  //////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////
  // Implement the branch cache as structural/dataflow verilog //
  //////////////////////////////////////////////////////////////
  // Instantiate two read register decoders.
  Decoder_3_8 iREAD_CURR (.RegId(SrcCurr), .en(1'b1), .Wordline(Wordline_curr));
  Decoder_3_8 iREAD_PREV (.RegId(SrcPrev), .en(1'b1), .Wordline(Wordline_prev));

  // Cache is only one write enabled if both enable and wen are high.
  assign write_enable = enable & wen;

  // Instantiate a single write decoder.
  WriteDecoder_3_8 iWRITE (.RegId(DstPrev), .WriteReg(write_enable), .Wordline(Wordline_dst));

  // Vector instantiate 8 registers to track the last 8 branch instructions.
  Register #(WIDTH) iBRANCH_CACHE[0:7] (.clk({8{clk}}), .rst({8{rst}}), .D(DstData), .WriteReg(Wordline_dst), .ReadEnable1(Wordline_curr), .ReadEnable2(Wordline_prev), .Bitline1(data_curr), .Bitline2(data_prev));

  // Read the data from the current location in the cache only if the cache is enabled.
  assign SrcDataCurr = (enable) ? data_curr : {WIDTH{1'b0}};

  // Read the data from the previous location in the cache only if the cache is enabled.
  assign SrcDataPrev = (enable) ? data_prev : {WIDTH{1'b0}};

endmodule

`default_nettype wire // Reset default behavior at the end