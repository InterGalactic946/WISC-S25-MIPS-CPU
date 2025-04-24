//////////////////////////////////////////////////
// memory.sv                                    //
// This module implements a simple memory unit  //
// for reading and writing data to a memory     //
// array. It supports both reading and writing  //
// operations based on the control signals      //
// and the address provided.                    //
// The memory is initialized with data from a   //
// file on reset.                               //
// This memory writes in 1 cycle, and reads in  //
// 4 cycles.                                     //
//////////////////////////////////////////////////

module memory(data_out, data_in, addr, enable, wr, clk, rst, data_valid);

    // Parameter for memory address width
    parameter ADDR_WIDTH = 16;

    output logic data_valid;                // Output signal indicating when the data_out is valid
    output logic [15:0] data_out;           // 16-bit data output read from memory
    input logic [15:0] data_in;             // 16-bit data input to be written into memory
    input logic [ADDR_WIDTH-1:0] addr;      // Address for memory read/write operation
    input logic enable;                     // Enable signal for memory access
    input logic wr;                         // Write enable (1 for write, 0 for read)
    input logic clk;                        // System clock
    input logic rst;                        // Synchronous, active-high reset


    // Internal signals to simulate a 4-cycle latency for memory reads
    logic [15:0] data_out_4;
    logic [15:0] data_out_3, data_out_2, data_out_1;
    logic data_valid_4;
    logic data_valid_3, data_valid_2, data_valid_1;

    // Instantiate the memory model structure
    logic [15:0] mem_addr [0:65535]; 
    logic [15:0] data_mem [0:65535];


    /////////////////////////////////////////////////////////////////////////////
    // Combinational logic for reading from memory                             //
    // - Only when memory is enabled and not in write mode.                    //
    // - Data is read from memory and marked valid.                            //
    /////////////////////////////////////////////////////////////////////////////
    assign data_out_4 = (enable && !wr) ? data_mem[addr[ADDR_WIDTH-1:1]] : 16'h0000;
    assign data_valid_4 = (enable && !wr);

    /////////////////////////////////////////////////////////////////////////////
    // Memory write and initialization logic                                   //
    // - On reset, memory is loaded from a file once.                          //
    // - On write enable, input data is written to memory.                     //
    /////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk) begin
        if (rst) begin
            $readmemh("./tests/loadfile_all.img", data_mem);  // Load memory contents
            mem_addr <= '{default: 16'hxxxx};                 // Invalidate addresses
        end else if (enable && wr) begin
            // Store word operation (write to data memory)
            mem_addr[addr[ADDR_WIDTH-1:1]] <= addr;
            data_mem[addr[ADDR_WIDTH-1:1]] <= data_in;
        end
    end

    /////////////////////////////////////////////////////////////////////////////
    // Pipeline registers for simulating 4-cycle read latency                  //
    // - Each cycle, values are shifted down the pipeline.                     //
    // - After 4 cycles, the original read value appears on data_out.          //
    /////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk) begin
        if (rst) begin
            // Reset all output and pipeline stages
            data_out_3 <= 16'h0000;
            data_out_2 <= 16'h0000;
            data_out_1 <= 16'h0000;
            data_out   <= 16'h0000;

            data_valid_3 <= 1'b0;
            data_valid_2 <= 1'b0;
            data_valid_1 <= 1'b0;
            data_valid   <= 1'b0;
        end else begin
            // Shift data and valid signals through pipeline
            data_out_3 <= data_out_4;
            data_out_2 <= data_out_3;
            data_out_1 <= data_out_2;
            data_out   <= data_out_1;

            data_valid_3 <= data_valid_4;
            data_valid_2 <= data_valid_3;
            data_valid_1 <= data_valid_2;
            data_valid   <= data_valid_1;
        end
    end

endmodule
