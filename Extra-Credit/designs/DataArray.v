//Data Array of 64 cache sets
//Each set has 2 blocks (ways)
//Each block will have 8 words
//BlockEnable and WordEnable are one-hot
//WriteEnable is one on writes and zero on reads
module DataArray(input clk, input rst, input [15:0] DataIn, input Write, input WaySelect, input [63:0] SetEnable, input [7:0] WordEnable, output [15:0] DataOut_first_way, output [15:0] DataOut_second_way);
	DataSet set[63:0] (.clk(clk), .rst(rst), .DataIn(DataIn), .Write(Write), .WaySelect(WaySelect), .SetEnable(SetEnable), .WordEnable(WordEnable), .DataOut_first_way(DataOut_first_way), .DataOut_second_way(DataOut_second_way));
endmodule

// Each set has 2 "ways" or cache lines
module DataSet(input clk, input rst, input [15:0] DataIn, input Write, input WaySelect, input SetEnable, input [7:0] WordEnable, output [15:0] DataOut_first_way, output [15:0] DataOut_second_way);
    wire WriteEnable_first_way;
    wire WriteEnable_second_way;

	// Either the first or second way is selected on a write.
	assign WriteEnable_first_way  = Write & ~WaySelect;
	assign WriteEnable_second_way  = Write & WaySelect;

	Block blk_first_way (.clk(clk), .rst(rst), .Din(DataIn), .WriteEnable(WriteEnable_first_way), .Enable(SetEnable), .WordEnable(WordEnable), .Dout(DataOut_first_way));
	Block blk_second_way (.clk(clk), .rst(rst), .Din(DataIn), .WriteEnable(WriteEnable_second_way), .Enable(SetEnable), .WordEnable(WordEnable), .Dout(DataOut_second_way));
endmodule

// 64 byte (8 word) cache block
module Block( input clk,  input rst, input [15:0] Din, input WriteEnable, input Enable, input [7:0] WordEnable, output [15:0] Dout);
	wire [7:0] WordEnable_real;
	assign WordEnable_real = {8{Enable}} & WordEnable; // Only for the enabled cache block, you enable the specific word
	DWord dw[7:0] (.clk(clk), .rst(rst), .Din(Din), .WriteEnable(WriteEnable), .Enable(WordEnable_real), .Dout(Dout));
endmodule


// Each word has 16 bits
module DWord( input clk,  input rst, input [15:0] Din, input WriteEnable, input Enable, output [15:0] Dout);
	DCell dc[15:0] (.clk(clk), .rst(rst), .Din(Din[15:0]), .WriteEnable(WriteEnable), .Enable(Enable), .Dout(Dout[15:0]));
endmodule

// A cell is a flop
module DCell( input clk,  input rst, input Din, input WriteEnable, input Enable, output Dout);
	wire q;
	assign Dout = (Enable & ~WriteEnable) ? q:'bz;
	dff dffd (.q(q), .d(Din), .wen(Enable & WriteEnable), .clk(clk), .rst(rst));
endmodule

