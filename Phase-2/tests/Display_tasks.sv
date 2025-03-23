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
  task automatic display_decoded_info(input logic [3:0] opcode, input logic [3:0] rs, input logic [3:0] rt, input logic [3:0] rd, input logic [15:0] ALU_imm, input logic actual_taken, input logic [15:0] actual_target, output string instr_state);
      begin
          // Local var for instruction name.

          // Decode the instruction name.
          get_instr_name(.opcode(opcode), .instr_name(instr_name));  // Decode the opcode to instruction name
          
          case (opcode)
              4'h0, 4'h1, 4'h2, 4'h3, 4'h7: // Instructions with 2 registers (like ADD, SUB, XOR, etc.)
                instr_state = $sformatf("Opcode = 0b%4b, Instr: %s, rs = 0x%h, rt = 0x%h, rd = 0x%h.", opcode, instr_name, rs, rt, rd);
              4'h4, 4'h5, 4'h6, 4'h8, 4'h9: // LW and SW have an immediate but no rd register.
                instr_state = $sformatf("Opcode = 0b%4b, Instr: %s, rs = 0x%h, rt = 0x%h, imm = 0x%h.", opcode, instr_name, rs, rd, imm);
              4'hA, 4'hB: // LLB and LHB have an immediate but no rt register.
                instr_state = $sformatf("Opcode = 0b%4b, Instr: %s, rd = 0x%h, imm = 0x%h.", opcode, instr_name, rd, imm);              
              4'hC, 4'hD: begin // B, BR instructions
                if (opcode === 4'hC) begin
                    if (actual_taken)
                        instr_state = $sformatf("Branch (B) is actually taken. The actual target is: 0x%h.", actual_target);
                    else 
                        instr_state = $sformatf("Branch (B) is actually NOT taken. The actual target is: 0x%h.", actual_target);
                end else if (opcode === 4'hD) begin
                    if (actual_taken)
                        instr_state = $sformatf("Branch (BR) is actually taken. The actual target is: 0x%h.", actual_target);
                    else 
                        instr_state = $sformatf("Branch (BR) is actually NOT taken. The actual target is: 0x%h.", actual_target);
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
            begin
                4'h0: instr_name = $sformatf("ADD R%0d, R%0d, R%0d", rd, rs, rt);        // 0000: Addition
                4'h1: instr_name = $sformatf("SUB R%0d, R%0d, R%0d", rd, rs, rt);        // 0001: Subtraction
                4'h2: instr_name = $sformatf("XOR R%0d, R%0d, R%0d", rd, rs, rt);        // 0010: Bitwise XOR
                4'h3: instr_name = $sformatf("RED R%0d, R%0d, R%0d", rd, rs, rt);        // 0011: Reduction Addition
                4'h4: instr_name = $sformatf("SLL R%0d, R%0d, R%0d", rd, rs, rt);        // 0100: Shift Left Logical
                4'h5: instr_name = $sformatf("SRA R%0d, R%0d, R%0d", rd, rs, rt);        // 0101: Shift Right Arithmetic
                4'h6: instr_name = $sformatf("ROR R%0d, R%0d, R%0d", rd, rs, rt);        // 0110: Rotate Right
                4'h7: instr_name = $sformatf("PADDSB R%0d, R%0d, R%0d", rd, rs, rt);     // 0111: Parallel Sub-word Addition
                4'h8: instr_name = $sformatf("LW R%0d, R%0d, 0x%h", rd, rs, ALU_imm);    // 1000: Load Word
                4'h9: instr_name = $sformatf("SW R%0d, R%0d, 0x%h", rd, rs, ALU_imm);    // 1001: Store Word
                4'hA: instr_name = $sformatf("LLB R%0d, 0x%h", rd, ALU_imm);             // 1010: Load Low Byte
                4'hB: instr_name = $sformatf("LLB R%0d, 0x%h", rd, ALU_immm);            // 1011: Load High Byte
                4'hC: instr_name = $sformatf("B %3b, TARGET: 0x%h", cc, actual_target);  // 1100: Branch (Conditional)
                4'hD: instr_name = $sformatf("BR %3b, R%0d", cc, rs);                    // 1101: Branch (Unconditional)
                4'hE: instr_name = $sformatf("PCS R%0d", rd);                            // 1110: PCS (Program Counter Store)
                4'hF: instr_name = "HLT";                                                // 1111: Halt
                default: instr_name = "INVALID";                                         // Invalid opcode
            end
      endcase
   endtask

endpackage
