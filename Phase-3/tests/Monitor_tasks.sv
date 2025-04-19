///////////////////////////////////////////////////////////////
// Monitor_tasks.sv: Package containing tasks to log memory. //
// This package contains tasks related to log contents       //
// of data memory, register file, and BTB, BHT contents.     //
///////////////////////////////////////////////////////////////
package Monitor_tasks;
  
  ///////////////////////////////////////
  // Declare state types as enumerated //
  ///////////////////////////////////////
  typedef enum logic [1:0] {STRONG_NOT_TAKEN, WEAK_NOT_TAKEN, WEAK_TAKEN, STRONG_TAKEN} state_t;

  // Struct Definitions for BTB, BHT, cache, and data memory models.
  typedef struct {
    logic [15:0] PC_addr;
    state_t prediction;
    logic valid;
  } model_BHT_t;
  
  typedef struct {
    logic [15:0] PC_addr; 
    logic [15:0] target;
  } model_BTB_t;

  // Tag block each entry holds LRU, valid and 6-bit tag along with full address for debugging
  typedef struct {
    logic [5:0] tag;   // Tag bits
    logic valid;       // Valid bit
    logic lru;         // LRU bit
  } tag_block_t;

  // Tag set each entry holds two instances of a tag block
  typedef struct {
    tag_block_t first_way;
    tag_block_t second_way;
  } tag_set_t;

  // Tag array each entry holds 64 instances of tag set.
  typedef struct {
    tag_set_t tag_set[0:63];
  } tag_array_t;

  // Data entry each entry holds two blocks of 2B each storing 8 words, overall 16B per cache line and 32B per cache set.
  typedef struct {
    logic [15:0] first_way[0:7];
    logic [15:0] second_way[0:7];
  } data_set_t;

  // Infer the data array as 64 data sets = 2048B (2KB) cache.
  typedef struct {
    data_set_t data_set[0:63];
  } data_array_t;

  // Infer the cache as a data array and tag array.
  typedef struct {
    data_array_t cache_data_array;
    tag_array_t cache_tag_array;
  } model_cache_t;

  typedef struct {
    logic [15:0] mem_addr [0:65535]; 
    logic [15:0] data_mem [0:65535];
  } model_data_mem_t;

  // Structure to store debug information for each pipeline stage
  typedef struct {
    string fetch_msgs[0:4];

    string decode_msgs[0:4];
    string instr_full_msg;

    string execute_msg;

    string memory_msg;

    string wb_msg;
  } debug_info_t;


  // Task: Dumps contents of DUT and model BHT and BTB memory.
  task automatic log_BTB_BHT_dump(
    input model_BHT_t model_BHT [0:7],  
    input model_BTB_t model_BTB [0:7]
  );

    integer i, file;
    int clock_cycle;
    logic [15:0] model_PC_BHT, model_pred;
    logic [15:0] model_PC_BTB, model_target;

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
          $fdisplay(file, "|        DYNAMIC BRANCH PREDICTOR MEMORY DUMP - CLOCK CYCLE %0d               |", clock_cycle);
          $fdisplay(file, "===============================================================================");
          $fdisplay(file, "-------------------------------------|----------------------------------------");
          $fdisplay(file, "                 BHT                 |                   BTB                  ");
          $fdisplay(file, "-------------------------------------|----------------------------------------");
          $fdisplay(file, "    IF_ID_PC_curr | PREDICTION       |      IF_ID_PC_curr | TARGET            ");

          for (i = 0; i < 8; i = i + 1) begin  
              // Fetch values from Model and DUT  
              model_PC_BHT = model_BHT[i].PC_addr;
              model_pred   = model_BHT[i].prediction;

              model_PC_BTB = model_BTB[i].PC_addr;
              model_target = model_BTB[i].target;
              
              // Write to File with newline
              $fwrite(file, "         0x%04X         %2b           |", (model_PC_BHT === 16'hxxxx) ? 16'hXXXX : model_PC_BHT, model_pred);
              $fdisplay(file, "         0x%04X       0x%04X   ", (model_PC_BTB === 16'hxxxx) ? 16'hXXXX : model_PC_BTB, model_target);
          end  

          $fdisplay(file, "\n");

          // Close the file
          $fclose(file);
      end
  endtask


  // Task: Prints data memory to a file with the current clock cycle.
  task automatic log_data_dump(input model_data_mem_t model_data_mem, 
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
      title = $sformatf("| DATA MEMORY DUMP - CLOCK CYCLE %0d  |", clock_cycle);

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
              $fwrite(file, "| 0x%04X  | 0x%04X | 0x%04X |  %s   |\n",
                      model_addr, model_val, dut_val, 
                      (model_val === dut_val) ? "YES" : "NO");
          end
      end

      // Write the footer and close the file
      $fwrite(file, "=======================================\n");
      $fwrite(file, "\n");
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
          // $display("ADDR: %04x, VALUE: %04x", addr, regfile[addr]);
      end

      // Write the footer and close the file
      $fwrite(file, "%s\n", separator);
      $fwrite(file, "\n");
      $fclose(file);
  endtask

  
  // Task: Returns the name of the instruction that was fetched.
  task automatic get_instr_name(input logic [3:0] opcode, output string instr_name);
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
  task automatic display_decoded_info(input logic [3:0] opcode, input logic [3:0] rs, input logic [3:0] rt, input logic [3:0] rd, input logic [15:0] ALU_imm, input logic [2:0] flag_reg, input logic actual_taken, input logic [15:0] actual_target, output string instr_state);
      begin
          // Local var for instruction name.
          string instr_name;

          // Decode the instruction name.
          get_instr_name(.opcode(opcode), .instr_name(instr_name));  // Decode the opcode to instruction name
          
          case (opcode)
              4'h0, 4'h1, 4'h2, 4'h3, 4'h7: // Instructions with 2 registers (like ADD, SUB, XOR, etc.)
                instr_state = $sformatf("Opcode = 0b%4b, Instr: %s, rs = 0x%h, rt = 0x%h, rd = 0x%h.", opcode, instr_name, rs, rt, rd);
              4'h4, 4'h5, 4'h6, 4'h8, 4'h9: // LW and SW have an immediate but no rd register.
                instr_state = $sformatf("Opcode = 0b%4b, Instr: %s, rs = 0x%h, rt = 0x%h, imm = 0x%h.", opcode, instr_name, rs, rd, ALU_imm);
              4'hA, 4'hB: // LLB and LHB have an immediate but no rt register.
                instr_state = $sformatf("Opcode = 0b%4b, Instr: %s, rd = 0x%h, imm = 0x%h.", opcode, instr_name, rd, ALU_imm);              
              4'hC, 4'hD: begin // B, BR instructions
                if (opcode === 4'hC) begin
                    if (actual_taken)
                        instr_state = $sformatf("Flag state: ZF = %b, VF = %b, NF = %b. Branch (B) is actually taken. The actual target is: 0x%h.", flag_reg[2], flag_reg[1], flag_reg[0], actual_target);
                    else 
                        instr_state = $sformatf("Flag state: ZF = %b, VF = %b, NF = %b. Branch (B) is actually NOT taken. The actual target is: 0x%h.", flag_reg[2], flag_reg[1], flag_reg[0], actual_target);
                end else if (opcode === 4'hD) begin
                    if (actual_taken)
                        instr_state = $sformatf("Flag state: ZF = %b, VF = %b, NF = %b. Branch (BR) is actually taken. The actual target is: 0x%h.", flag_reg[2], flag_reg[1], flag_reg[0], actual_target);
                    else 
                        instr_state = $sformatf("Flag state: ZF = %b, VF = %b, NF = %b. Branch (BR) is actually NOT taken. The actual target is: 0x%h.", flag_reg[2], flag_reg[1], flag_reg[0], actual_target);
                end
              end
              4'hE: // (PCS) does not have registers like `rs`, `rt`. It only has a destination register `rd`.
                instr_state = $sformatf("Opcode = 0b%4b, Instr: %s, rd = 0x%h.", opcode, instr_name, rd);
              default: // HLT/Invalid opcode
                instr_state = $sformatf("Opcode = 0b%4b, Instr: %s.", opcode, instr_name);
          endcase
      end
  endtask


  // Task: To get the full instruction string.
  task automatic get_full_instruction (
      input logic [3:0] opcode, 
      input logic [3:0] rs, 
      input logic [3:0] rt, 
      input logic [3:0] rd, 
      input logic [15:0] ALU_imm, 
      input logic [2:0] cc, 
      input logic [15:0] actual_target,
      output string instr_name
  );
      case (opcode)
          4'h0: begin 
            if (rd === 0 && rs === 0 && rt === 0)
                instr_name = $sformatf("NOP");                                     // 0000: NOP
            else
                instr_name = $sformatf("ADD R%0d, R%0d, R%0d", rd, rs, rt);        // 0000: Addition
          end
          4'h1: instr_name = $sformatf("SUB R%0d, R%0d, R%0d", rd, rs, rt);        // 0001: Subtraction
          4'h2: instr_name = $sformatf("XOR R%0d, R%0d, R%0d", rd, rs, rt);        // 0010: Bitwise XOR
          4'h3: instr_name = $sformatf("RED R%0d, R%0d, R%0d", rd, rs, rt);        // 0011: Reduction Addition
          4'h4: instr_name = $sformatf("SLL R%0d, R%0d, 0x%h", rd, rs, ALU_imm);   // 0100: Shift Left Logical
          4'h5: instr_name = $sformatf("SRA R%0d, R%0d, 0x%h", rd, rs, ALU_imm);   // 0101: Shift Right Arithmetic
          4'h6: instr_name = $sformatf("ROR R%0d, R%0d, 0x%h", rd, rs, ALU_imm);   // 0110: Rotate Right
          4'h7: instr_name = $sformatf("PADDSB R%0d, R%0d, R%0d", rd, rs, rt);     // 0111: Parallel Sub-word Addition
          4'h8: instr_name = $sformatf("LW R%0d, R%0d, 0x%h", rd, rs, ALU_imm);    // 1000: Load Word
          4'h9: instr_name = $sformatf("SW R%0d, R%0d, 0x%h", rd, rs, ALU_imm);    // 1001: Store Word
          4'hA: instr_name = $sformatf("LLB R%0d, 0x%h", rd, ALU_imm);             // 1010: Load Low Byte
          4'hB: instr_name = $sformatf("LHB R%0d, 0x%h", rd, ALU_imm);             // 1011: Load High Byte (Fixed Typo)
          4'hC: instr_name = $sformatf("B %3b, TARGET: 0x%h", cc, actual_target);  // 1100: Branch (Conditional)
          4'hD: instr_name = $sformatf("BR %3b, R%0d", cc, rs);                    // 1101: Branch (Unconditional)
          4'hE: instr_name = $sformatf("PCS R%0d", rd);                            // 1110: PCS (Program Counter Store)
          4'hF: instr_name = "HLT";                                                // 1111: Halt
          default: instr_name = "INVALID";                                         // Invalid opcode
      endcase
  endtask

endpackage