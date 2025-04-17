//Tag Array of 64 sets
//Each set will have 2 blocks
//Each block will have 1 byte
//BlockEnable is one-hot
//WriteEnable is one on writes and zero on reads
module MetaDataArray(input clk, input rst, input [7:0] DataIn_first_way, input [7:0] DataIn_second_way, input Write, input [63:0] SetEnable, output [7:0] DataOut_first_way, output [7:0] DataOut_second_way);
	MetaDataSet set[63:0] (.clk(clk), .rst(rst), .DataIn_first_way(DataIn_first_way), .DataIn_second_way(DataIn_second_way), .Write(Write), .SetEnable(SetEnable), .DataOut_first_way(DataOut_first_way), .DataOut_second_way(DataOut_second_way));
endmodule

// Each set has 2 "ways" or cache lines
module MetaDataSet(input clk, input rst, input [7:0] DataIn_first_way, input [7:0] DataIn_second_way, input Write, input SetEnable, output [7:0] DataOut_first_way, output [7:0] DataOut_second_way);
	MBlock Mblk_first_way ( .clk(clk), .rst(rst), .Din(DataIn_first_way), .WriteEnable(Write), .Enable(SetEnable), .Dout(DataOut_first_way));
	MBlock Mblk_second_way ( .clk(clk), .rst(rst), .Din(DataIn_second_way), .WriteEnable(Write), .Enable(SetEnable), .Dout(DataOut_second_way));
endmodule


module MBlock( input clk,  input rst, input [7:0] Din, input WriteEnable, input Enable, output [7:0] Dout);
	MCell mc[7:0]( .clk(clk), .rst(rst), .Din(Din[7:0]), .WriteEnable(WriteEnable), .Enable(Enable), .Dout(Dout[7:0]));
endmodule

module MCell( input clk,  input rst, input Din, input WriteEnable, input Enable, output Dout);
	wire q;
	assign Dout = (Enable & ~WriteEnable) ? q:'bz;
	dff dffm(.q(q), .d(Din), .wen(Enable & WriteEnable), .clk(clk), .rst(rst));
endmodule

