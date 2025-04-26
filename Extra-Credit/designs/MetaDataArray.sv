//Tag Array of 64 sets
//Each set will have 2 blocks
//Each block will have 1 byte
//BlockEnable is one-hot
//WriteEnable is one on writes and zero on reads
// module MetaDataArray(input clk, input rst, input [7:0] DataIn_first_way, input [7:0] DataIn_second_way, input Write, input [63:0] SetEnable, input Set_First_LRU, output [7:0] DataOut_first_way, output [7:0] DataOut_second_way);
//     wire [7:0] DataIn_first;
// 	wire [7:0] DataIn_second;
// 	assign DataIn_first = {DataIn_first_way[7:1], Set_First_LRU};
// 	assign DataIn_second = {DataIn_second_way[7:1], ~Set_First_LRU};
	
// 	MetaDataSet set[63:0] (.clk({64{clk}}), .rst({64{rst}}), .DataIn_first_way(DataIn_first), .DataIn_second_way(DataIn_second), .Write(Write), .SetEnable(SetEnable), .DataOut_first_way(DataOut_first_way), .DataOut_second_way(DataOut_second_way));
// endmodule

// // Each set has 2 "ways" or cache lines
// module MetaDataSet(input clk, input rst, input [7:0] DataIn_first_way, input [7:0] DataIn_second_way, input Write, input SetEnable, output [7:0] DataOut_first_way, output [7:0] DataOut_second_way);
// 	MBlock Mblk_first_way ( .clk(clk), .rst(rst), .Din(DataIn_first_way), .WriteEnable(Write), .Enable(SetEnable), .Dout(DataOut_first_way));
// 	MBlock Mblk_second_way ( .clk(clk), .rst(rst), .Din(DataIn_second_way), .WriteEnable(Write), .Enable(SetEnable), .Dout(DataOut_second_way));
// endmodule


// module MBlock( input clk, input rst, input [7:0] Din, input WriteEnable, input Enable, output [7:0] Dout);
// 	MCell mc[7:0]( .clk(clk), .rst(rst), .Din(Din[7:0]), .WriteEnable(WriteEnable), .Enable(Enable), .Dout(Dout[7:0]));
// endmodule

// module MCell( input clk, input rst, input Din, input WriteEnable, input Enable, output Dout);
// 	wire q;
// 	assign Dout = (Enable) ? q:'bz;
// 	dff dffm(.q(q), .d(Din), .wen(Enable & WriteEnable), .clk(clk), .rst(rst));
// endmodule

module MetaDataArray #(
    parameter TAG_WIDTH = 8,
    parameter NUM_BLOCKS = 64,
    parameter NUM_WAYS = 2
)(
	input clk,
	input rst,
	input [7:0] DataIn_first_way,
	input [7:0] DataIn_second_way,
	input Write,
	input [5:0] SetEnable,
	input Set_First_LRU,
	output [7:0] DataOut_first_way,
	output [7:0] DataOut_second_way
);

    // Tag and valid bit arrays
    reg [TAG_WIDTH-1:0] tag_array_first_way [NUM_BLOCKS-1:0];
    reg [TAG_WIDTH-1:0] tag_array_second_way [NUM_BLOCKS-1:0];

    genvar i;

    // Write logic
    always @(posedge clk) begin
        if (rst) begin
	    tag_array_first_way <= '{default: '0};
	    tag_array_second_way <= '{default: '0};
	end
        else if (Write) begin
            tag_array_second_way[SetEnable]   <= {DataIn_second_way[7:1], ~Set_First_LRU};
            tag_array_first_way[SetEnable]    <= {DataIn_first_way[7:1], Set_First_LRU};
        end
    end

    assign DataOut_first_way    = tag_array_first_way[SetEnable];
    assign DataOut_second_way   = tag_array_second_way[SetEnable];

endmodule
