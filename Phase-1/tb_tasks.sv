package tb_tasks;

  // Task to initialize testbench signals
  task automatic Initialize(ref logic clk, ref logic rst_n);
    begin
      clk = 1'b0;
      @(negedge clk) rst_n = 1'b0;
      repeat (2) @(posedge clk); // Wait for 2 clock cycles
      @(negedge clk) rst_n = 1'b1; // Deassert reset
      repeat (10) @(posedge clk); // Allow system to stabilize
    end
  endtask

  // Task to load an instruction image into memory
  task automatic LoadImage(input string filename, ref logic [31:0] memory [0:1023]);
    begin
      // Use $readmemh to load the file contents into memory
      $readmemh(filename, memory);
    end
  endtask

  // Task to fetch an instruction from memory
  task automatic FetchInstruction(ref logic [31:0] memory [0:1023], ref logic [31:0] pc, output logic [31:0] instr);
    begin
      // Fetch instruction from memory at PC
      instr = memory[pc >> 2]; // Assuming PC is byte-addressed and memory is word-addressed
      $display("Fetching instruction at PC = %h: %h", pc, instr);
    end
  endtask

  // Task to decode an instruction and identify its opcode and operands
  task automatic DecodeInstruction(input logic [31:0] instr, output logic [3:0] opcode, output logic [4:0] rs, output logic [4:0] rt, output logic [4:0] rd, output logic [15:0] imm);
    begin
      // Decode the instruction
      opcode = instr[31:28];   // Opcode (4 bits)
      rs = instr[27:23];       // rs (5 bits)
      rt = instr[22:18];       // rt (5 bits)
      rd = instr[17:13];       // rd (5 bits)
      imm = instr[15:0];       // immediate value (16 bits)
      $display("Decoded instruction: Opcode = %b, rs = %d, rt = %d, rd = %d, imm = %h", opcode, rs, rt, rd, imm);
    end
  endtask

  // Task to execute an instruction
  task automatic ExecuteInstruction(input logic [3:0] opcode, input logic [31:0] rs_data, input logic [31:0] rt_data, input logic [15:0] imm, output logic [31:0] result);
    begin
      case (opcode)
        4'b0000: result = rs_data + rt_data;          // ADD
        4'b0001: result = rs_data - rt_data;          // SUB
        4'b0010: result = rs_data ^ rt_data;          // XOR
        4'b0011: result = rs_data * rt_data;          // RED (for example, can be any special operation)
        4'b0100: result = rt_data << imm;             // SLL
        4'b0101: result = rt_data >>> imm;            // SRA
        4'b0110: result = {rt_data[0], rt_data[31:1]}; // ROR (example)
        4'b0111: result = rt_data;                    // PADDSB (example)
        4'b1000: result = rs_data + imm;              // LW
        4'b1001: result = rs_data + imm;              // SW
        4'b1010: result = rs_data;                    // LLB
        4'b1011: result = rt_data;                    // LHB
        4'b1100: result = 0;                          // B (branch - will not calculate a result here)
        4'b1101: result = rs_data;                    // BR (branch)
        4'b1110: result = rs_data;                    // PCS
        4'b1111: result = 32'b0;                      // HLT (halt)
        default: result = 32'b0;                      // Default to 0 if unknown opcode
      endcase
      $display("Executed instruction with result: %h", result);
    end
  endtask

  // Task to simulate memory access (for LW and SW)
  task automatic MemoryAccess(input logic [31:0] addr, input logic [31:0] data_in, output logic [31:0] data_out, input logic mem_read, input logic mem_write, ref logic [31:0] memory [0:1023]);
    begin
      if (mem_read) begin
        data_out = memory[addr >> 2];  // Read from memory
        $display("Read from memory at address %h: %h", addr, data_out);
      end
      if (mem_write) begin
        memory[addr >> 2] = data_in;   // Write to memory
        $display("Written to memory at address %h: %h", addr, data_in);
      end
    end
  endtask

  // Task to write back the result to the register file
  task automatic WriteBack(ref logic [31:0] regfile [0:31], input logic [4:0] rd, input logic [31:0] result);
    begin
      regfile[rd] = result;
      $display("Written back to register x%0d: %h", rd, result);
    end
  endtask

endpackage
