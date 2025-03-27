////////////////////////////////////////////////////////////
// Model_tasks.sv: Task definitions for CPU modeling.     //
// This package contains tasks to model the behavior      //
// of the CPU core, including tasks for instruction       //
// fetching, decoding, execution, and managing memory     //
// and registers. It facilitates modeling of the CPU's    //
// various components like the ALU, control unit, and     //
// program counter during simulation.                     //
////////////////////////////////////////////////////////////
package Display_tasks;

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


task automatic get_hazard_messages(
    ref logic pc_stall, if_id_stall, if_flush, id_flush,    // Stall and flush signals
    ref logic br_hazard, b_hazard, load_use_hazard, hlt,    // Hazard type signals
    output string pc_stall_msg,                             // Output message for PC stage
    output string if_id_stall_msg,                          // Output message for IF_ID stage
    output string if_flush_msg,                             // Output message for IF flush stage
    output string id_flush_msg                              // Output message for ID flush stage
);

    // Variables for hazard type message and flush type.
    string hazard_type = "";
    string flush_type = "";

    // Determine the type of hazard and generate the appropriate message.
    if (load_use_hazard) begin
        hazard_type = "load-to-use hazard";
    end else if (br_hazard) begin
        hazard_type = "Branch (BR) hazard";
    end else if (b_hazard) begin
        hazard_type = "Branch (B) hazard";
    end else if (hlt) begin
        hazard_type = "HLT instruction";
    end

    // Initialize message strings
    pc_stall_msg = "";
    if_id_stall_msg = "";
    if_flush_msg = "";
    id_flush_msg = "";

    // Handle Flush Type Messages
    if (if_flush) begin
        flush_type = "mispredicted branch";
    end else if (id_flush) begin
        flush_type = hazard_type; // Use hazard type for ID flush if no mispredicted branch
    end else begin
        flush_type = ""; // No flush message
    end

    // Handle PC Stall Message.
    if (pc_stall) begin
        pc_stall_msg = $sformatf("[STALL]: PC stalled due to %s.", hazard_type);
    end

    // Handle IF_ID Stall Message.
    if (if_id_stall) begin
        if_id_stall_msg = $sformatf("[STALL]: IF_ID stalled due to %s.", hazard_type);
    end

    // Handle IF Flush Message.
    if (if_flush) begin
        if_flush_msg = $sformatf("[FLUSH]: IF flushed due to %s.", flush_type);
    end

    // Handle ID_EX Flush Message.
    if (id_flush) begin
        id_flush_msg = $sformatf("[FLUSH]: ID flushed due to %s.", flush_type);
    end
endtask

endpackage
