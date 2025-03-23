
module memory (data_out, data_in, addr, enable, wr, clk, rst);

   parameter ADDR_WIDTH = 16;
   output  [15:0] data_out;
   input [15:0]   data_in;
   input [ADDR_WIDTH-1 :0]   addr;
   input          enable;
   input          wr;
   input          clk;
   input          rst;
   wire [15:0]    data_out;
   
   model_data_mem_t data_memory;
   
   assign data_out = (enable && !wr) ? data_memory.data_mem[addr[ADDR_WIDTH-1:1]] : 0; // Read

  always_ff @(posedge clk) begin
      if (rst) begin
          // Initialize the data memory on reset.
          $readmemh("./tests/data.img", data_memory.data_mem);
          data_memory.mem_addr <= '{default: 16'hxxxx};
      end 
      else if (enable && wr) begin // SW (store word)
          // Save the address that was used to access memory
          data_memory.mem_addr[addr[ADDR_WIDTH-1:1]] <= addr;
          data_memory.data_mem[addr[ADDR_WIDTH-1:1]] <= data_in;
      end
  end

endmodule 
