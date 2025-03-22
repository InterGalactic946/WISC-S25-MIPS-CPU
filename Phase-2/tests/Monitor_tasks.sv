///////////////////////////////////////////////////////////////
// Monitor_tasks.sv: Package containing tasks to log memory. //
// This package contains tasks related to log contents       //
// of data memory, register file, and BTB, BHT contents.     //
///////////////////////////////////////////////////////////////
package Monitor_tasks;

  import Model_tasks::*;

  // Task: Dumps contents of DUT and model BHT and BTB memory.
  task automatic log_BTB_BHT_dump(
    input model_BHT_t model_BHT [0:15],  
    input model_BTB_t model_BTB [0:15], 
    input [15:0] dut_BHT [0:15], 
    input [15:0] dut_BTB [0:15] 
  );

    integer i, file;
    int clock_cycle;
    logic [15:0] model_PC_BHT, model_pred, dut_pred;
    logic [15:0] model_PC_BTB, model_target, dut_target;
    logic match_BHT, match_BTB;

      begin
          // Calculate the clock cycle
          clock_cycle = ($time / 10);

          // Open file in append mode to keep logs from previous runs.
          file = $fopen("./tests/output/logs/transcript/bht_btb_dump.log", "a");

          // Ensure file opened successfully.
          if (file == 0) begin
              $display("Error: Could not open file bht_btb_dump.log");
              disable log_BTB_BHT_dump;
          end

          // Write Header to File
          $fdisplay(file, "===============================================================================");
          $fdisplay(file, "|        DYNAMIC BRANCH PREDICTOR MEMORY DUMP - CLOCK CYCLE %0d              |", clock_cycle);
          $fdisplay(file, "===============================================================================");
          $fdisplay(file, "-------------------------------------|----------------------------------------");
          $fdisplay(file, "                 BHT                 |                   BTB                  ");
          $fdisplay(file, "-------------------------------------|----------------------------------------");
          $fdisplay(file, "IF_ID_PC_curr | Model | DUT | MATCH  | IF_ID_PC_curr |  Model  |  DUT  | MATCH");

          for (i = 0; i < 16; i = i + 1) begin  
              // Fetch values from Model and DUT  
              model_PC_BHT = model_BHT[i].PC_addr;
              model_pred   = model_BHT[i].prediction;
              dut_pred     = dut_BHT[i][1:0];
              match_BHT    = (model_pred === dut_pred);

              model_PC_BTB = model_BTB[i].PC_addr;
              model_target = model_BTB[i].target;
              dut_target   = dut_BTB[i];
              match_BTB    = (model_target === dut_target);
              
              // Write to File with newline
              $fwrite(file, "  0x%04X         %2b     %2b    %-3s    |", (model_PC_BHT === 16'hxxxx) ? 16'hXXXX : model_PC_BHT, model_pred, dut_pred, match_BHT ? "YES" : "NO");
              $fdisplay(file, "   0x%04X        0x%04X   0x%04X   %-3s", (model_PC_BTB === 16'hxxxx) ? 16'hXXXX : model_PC_BTB, model_target, dut_target, match_BTB ? "YES" : "NO");
          end  

          $fdisplay(file, "\n");

          // Close the file
          $fclose(file);
      end
  endtask


  // Task: Prints data memory to a file with the current clock cycle.
  task automatic log_data_dump(input model_BHT_t model_data_mem, 
                              input logic [15:0] dut_data_mem [0:65535]);
      integer addr;
      integer file;  // File handle
      logic [15:0] model_addr, model_val, dut_val;
      int clock_cycle;
      string title;
      
      // Calculate the clock cycle
      clock_cycle = ($time / 10);

      // Open file for writing (append mode)
      file = $fopen("./tests/output/logs/transcript/data_memory_dump.log", "a");
      if (file == 0) begin
          $display("Error: Unable to open file for writing.");
          return;
      end

      // Format the title with the current clock cycle
      title = $sformatf("| DATA MEMORY DUMP - CLOCK CYCLE %0d |", clock_cycle);

      // Write the centered header to the file
      $fwrite(file, "=======================================\n");
      $fwrite(file, "%s\n", title);
      $fwrite(file, "=======================================\n");
      $fwrite(file, "| ADDRESS |  Model |  DUT   | MATCH  |\n");

      // Iterate through the memory locations
      for (addr = 0; addr < 65536; addr++) begin
          model_addr = model_data_mem.mem_addr[addr];
          model_val = model_data_mem.data_mem[addr];
          dut_val = dut_data_mem[addr];

          // Only write values where model memory was accessed (not 'x')
          if (model_addr !== 16'hxxxx) begin
              $fwrite(file, "| 0x%04X  | 0x%04X | 0x%04X |  %s  |\n",
                      model_addr, model_val, dut_val, 
                      (model_val === dut_val) ? "YES" : "NO");
          end
      end

      // Write the footer and close the file
      $fwrite(file, "=======================================\n");
      $fclose(file);
  endtask


  // Task: Prints register file contents to a file with the current clock cycle.
  task automatic log_regfile_dump(input logic [15:0] regfile [0:15]);
      integer file;  // File handle
      int clock_cycle;
      string title, header, separator;

      // Calculate the clock cycle
      clock_cycle = ($time / 10);

      // Open file for writing (append mode)
      file = $fopen("./tests/output/logs/transcript/regfile_dump.log", "a");
      if (file == 0) begin
          $display("Error: Unable to open file for writing.");
          return;
      end

      // Format the title with the current clock cycle
      title = $sformatf("|  REGFILE DUMP - CLOCK CYCLE %0d |", clock_cycle);
      
      // Define a separator for formatting
      separator = "===================================";
      
      // Write the header
      $fwrite(file, "%s\n", separator);
      $fwrite(file, "%s\n", title);
      $fwrite(file, "%s\n", separator);
      $fwrite(file, "|     ADDRESS    |     VALUE      |\n");

      // Iterate through the 16 registers and write formatted values
      for (int addr = 0; addr < 16; addr++) begin
          $fwrite(file, "|      0x%04X    |     0x%04X     |\n", addr, regfile[addr]);
      end

      // Write the footer and close the file
      $fwrite(file, "%s\n", separator);
      $fclose(file);
  endtask


  // Task: Returns the name of the instruction that was fetched.
  task automatic decode_opcode(input logic [3:0] opcode, output string instr_name);
    begin
        case (opcode)
            4'h0: instr_name = "ADD";     // 0000: Addition
            4'h1: instr_name = "SUB";     // 0001: Subtraction
            4'h2: instr_name = "XOR";     // 0010: Bitwise XOR
            4'h3: instr_name = "RED";     // 0011: Reduction Addition
            4'h4: instr_name = "SLL";     // 0100: Shift Left Logical
            4'h5: instr_name = "SRA";     // 0101: Shift Right Arithmetic
            4'h6: instr_name = "ROR";     // 0110: Rotate Right
            4'h7: instr_name = "PADDSB";  // 0111: Parallel Sub-word Addition
            4'h8: instr_name = "LW";      // 1000: Load Word
            4'h9: instr_name = "SW";      // 1001: Store Word
            4'hA: instr_name = "LLB";     // 1010: Load Low Byte
            4'hB: instr_name = "LHB";     // 1011: Load High Byte
            4'hC: instr_name = "B";       // 1100: Branch (Conditional)
            4'hD: instr_name = "BR";      // 1101: Branch (Unconditional)
            4'hE: instr_name = "PCS";     // 1110: PCS (Program Counter Store)
            4'hF: instr_name = "HLT";     // 1111: Halt
            default: instr_name = "INVALID"; // Invalid opcode
        endcase
    end
  endtask


  // Task: Display the decoded information based on instruction type.
  task automatic display_decoded_info(input logic [3:0] opcode, input logic [3:0] rs, input logic [3:0] rt, input logic [3:0] rd, input logic [15:0] imm, input logic [2:0] cc, input logic [2:0] flag_reg);
      begin
          // Local var for instruction name.
          string instr_name;

          // Decode the instruction name.
          decode_opcode(.opcode(opcode), .instr_name(instr_name));  // Decode the opcode to instruction name
          
          case (opcode)
              4'h0, 4'h1, 4'h2, 4'h3, 4'h7: // Instructions with 2 registers (like ADD, SUB, XOR, etc.)
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s, rs = 0x%h, rt = 0x%h, rd = 0x%h.", opcode, instr_name, rs, rt, rd);
              4'h4, 4'h5, 4'h6, 4'h8, 4'h9: // LW and SW have an immediate but no rd register.
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s, rs = 0x%h, rt = 0x%h, imm = 0x%h.", opcode, instr_name, rs, rd, imm);
              4'hA, 4'hB: // LLB and LHB have an immediate but no rt register.
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s, rd = 0x%h, imm = 0x%h.", opcode, instr_name, rd, imm);
              4'hC: // B instruction does not have registers like `rs`, `rt`, or `rd`.
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s, CC: 0b%3b, imm = 0x%h, ZF = 0b%b, VF = 0b%b, NF = 0b%b.", opcode, instr_name, cc, imm, flag_reg[2], flag_reg[1], flag_reg[0]);
              4'hD: // BR instruction does not have registers like `rt`, or `rd`. It only has a source register `rs`.
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s, CC: 0b%3b, rs = 0x%h, ZF = 0b%b, VF = 0b%b, NF = 0b%b.", opcode, instr_name, cc, rs, flag_reg[2], flag_reg[1], flag_reg[0]); 
              4'hE: // (PCS) does not have registers like `rs`, `rt`. It only has a destination register `rd`.
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s, rd = 0x%h.", opcode, instr_name, rd);
              default: // HLT/Invalid opcode
                  $display("DUT Decoded instruction: Opcode = 0b%4b, Instr: %s.", opcode, instr_name);
          endcase
      end
  endtask

endpackage