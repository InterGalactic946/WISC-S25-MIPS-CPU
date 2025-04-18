//////////////////////////////////////
//
// Memory -- single cycle version
//
// written for CS/ECE 552, Spring '07
// Pratap Ramamurthy, 19 Mar 2006
//
// Modified for CS/ECE 552, Spring '18
// Gokul Ravi, 08 Mar 2018
//
// This is a byte-addressable,
// 16-bit wide memory
// Note: The last bit of the address has to be 0.
//
// All reads happen combinationally with zero delay.
// All writes occur on rising clock edge.
// Concurrent read and write not allowed.
//
// On reset, memory loads from file "loadfile_all.img".
// (You may change the name of the file in
// the $readmemh statement below.)
// File format:
//     @0
//     <hex data 0>
//     <hex data 1>
//     ...etc
//
//
//////////////////////////////////////

/*
# Single-Cycle Memory Specification

For the first stage of your project, you are tasked with designing a processor that executes each instruction in a single cycle. To achieve this, you will use the **single-cycle byte-addressable memory module** described below.

Since your single-cycle design must fetch instructions as well as read or write data in the same cycle, you will need to use **TWO** instances of this memory — one for data and one for instructions.

### Memory Module

```
                  +-------------+
 data_in[15:0] -->|             |--> data_out[15:0]
    addr[15:0] -->|   16-bit    |
        enable -->|   memory    |
            wr -->|   with      |
           clk -->|   variable  |
           rst -->|   address   |
    createdump -->|   width     |
                  |             |
                  +-------------+
```

### Memory Operation

During each cycle, the `enable` and `wr` inputs determine the function the memory will perform. Below is a table explaining the behavior:

| **enable** | **wr** | **Function**        | **data_out** |
|------------|--------|---------------------|--------------|
| 0          | X      | No operation        | 0            |
| 1          | 0      | Read M[addr]        | M[addr]      |
| 1          | 1      | Write data_in       | 0            |

- When **enable = 0**, there is no operation, and the data output is `0`.
- When **enable = 1 and wr = 0**, the memory will perform a read operation, and `data_out` will reflect the contents of `M[addr]`.
- When **enable = 1 and wr = 1**, the memory will perform a write operation, but the output will always be `0`.

### Read Cycle

During a read cycle, the `data_out` will immediately reflect the contents of the address specified by `addr` and will change in a flow-through manner if the address changes. For write operations, the `wr`, `addr`, and `data_in` signals must remain stable at the rising edge of the clock (`clk`).

---

## Initializing Your Memory

The memory is initialized from a file. By default, the file is named `loadfile_all.img`, but you can modify this in the Verilog source to any file name you prefer. The file is loaded at the first rising edge of the clock during reset. The simulator will look for this file in the same location as your `.v` files.

The format of the file is as follows:

```
@0
1234
1234
1234
1234
```

- `@0` specifies the starting address of the memory (in this case, address `0`).
- Each subsequent line represents a 4-digit hex number to be stored at the next address.
- You can specify any number of lines, up to the size of the memory.

The assembler will generate files in this format for you.
*/

module memory1c (data_out, data_in, data, addr, enable, wr, clk, rst);

   parameter ADDR_WIDTH = 16;
   output  [15:0] data_out;
   input [15:0]   data_in;
   input [ADDR_WIDTH-1 :0]   addr;
   input          enable;
   input          wr;
   input          clk;
   input          rst;
   input          data;
   wire [15:0]    data_out;
   
   reg [15:0]      mem [0:2**ADDR_WIDTH-1];
   reg            loaded;
   
   assign         data_out = (enable & (~wr))? {mem[addr[ADDR_WIDTH-1 :1]]}: 0; //Read
   initial begin
      loaded = 0;
   end

   always @(posedge clk) begin
      if (rst) begin
         //load loadfile_all.img
         if (!loaded) begin
            if (data)
              $readmemh("./tests/data.img", mem);
            else
              $readmemh("./tests/loadfile_all.img", mem);
            loaded = 1;
         end
          
      end
      else begin
         if (enable & wr) begin
	        mem[addr[ADDR_WIDTH-1 :1]] = data_in[15:0];       // The actual write
         end
      end
   end


endmodule 
