//////////////////////////////////////////////////
// memory.sv                                    //
// This module implements a simple memory unit  //
// for reading and writing data to a memory     //
// array. It supports both reading and writing  //
// operations based on the control signals      //
// and the address provided.                    //
// The memory is initialized with data from a   //
// file on reset.                               //
//////////////////////////////////////////////////

import Monitor_tasks::*;

module memory (
    output  [15:0] data_out,                // Output data read from memory
    input  [15:0] data_in,                  // Input data to be written to memory
    input  [ADDR_WIDTH-1:0] addr,           // Address to read/write from memory
    input          enable,                  // Enable signal for memory operations
    input          wr,                      // Write signal (1 for write, 0 for read)
    input          clk,                     // Clock signal for synchronizing operations
    input          rst                      // Reset signal to initialize memory
);

   // Parameter for the width of the address bus
   parameter ADDR_WIDTH = 16;

   // Internal signal to hold the output data
   logic [15:0]    data_out;

   // Declare a memory model structure
   model_data_mem_t data_memory;

   // Memory read operation: if enabled and not writing, read the data from the memory
   assign data_out = (enable && !wr) ? data_memory.data_mem[addr[ADDR_WIDTH-1:1]] : 0;

   // Always block triggered on the rising edge of the clock
   always_ff @(posedge clk) begin
      if (rst) begin
          // Initialize memory on reset: load data from a file and set memory address to 'xxxx'
          $readmemh("./tests/data.img", data_memory.data_mem);
          data_memory.mem_addr <= '{default: 16'hxxxx};
      end 
      else if (enable && wr) begin
          // Store word (SW) operation: Write the data to memory at the specified address
          data_memory.mem_addr[addr[ADDR_WIDTH-1:1]] <= addr;
          data_memory.data_mem[addr[ADDR_WIDTH-1:1]] <= data_in;
      end
   end

endmodule
