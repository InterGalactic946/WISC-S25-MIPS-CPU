///////////////////////////////////////////////////////////////
// Monitor_tasks.sv: Package containing tasks to log memory. //
// This package contains tasks related to log contents       //
// of data memory, register file, and BTB, BHT contents.     //
///////////////////////////////////////////////////////////////
package Monitor_tasks;

  import Model_tasks::*;

  // Task: Dumps contents of DUT and model BHT and BTB memory.
  task log_BTB_BHT_dump(
    input model_BHT_t model_BHT [0:15],  
    input model_BTB_t model_BTB [0:15], 
    input [15:0] dut_BHT [0:15], 
    input [15:0] dut_BTB [0:15] 
  );

    integer i, file;
    logic [15:0] model_PC_BHT, model_pred, dut_pred;
    logic [15:0] model_PC_BTB, model_target, dut_target;
    logic match_BHT, match_BTB;

      begin
          // Open file in append mode to keep logs from previous runs.
          file = $fopen("./tests/output/logs/transcript/bht_btb_dump.log", "a");

          // Ensure file opened successfully.
          if (file == 0) begin
              $display("Error: Could not open file bht_btb_dump.log");
              disable log_BTB_BHT_dump;
          end

          // Write Header to File
          $fdisplay(file, "===============================================================================");
          $fdisplay(file, "|        DYNAMIC BRANCH PREDICTOR MEMORY DUMP - CLOCK CYCLE %0d               |", $time);
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

endpackage