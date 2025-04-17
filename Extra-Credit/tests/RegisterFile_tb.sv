`default_nettype none // Set the default as none to avoid errors

///////////////////////////////////////////////////////////////////////////
// RegisterFile_tb.sv: Testbench for the 16-bit Register File            //
//                                                                       //
// This testbench verifies the functionality of the 16-bit register      //
// file by applying various stimulus patterns to test read and write     //
// operations. It ensures that data can be correctly stored and read     //
// from different registers, while also verifying that register 0        //
// remains hardwired to 0x0000 and cannot be written to. Edge cases,     //
// such as simultaneous reads and writes, are also tested to confirm     //
// proper behavior of the register file.                                 //
///////////////////////////////////////////////////////////////////////////
module RegisterFile_tb();

  reg [28:0] stim;	               // stimulus vector of type reg
  reg clk, rst;                    // system clock and active high synchronous reset
  wire [15:0] src_data_1;           // source data of first register
  wire [15:0] src_data_2;           // source data of second register
  reg [15:0] regfile[0:15];        // expected register file contents
  reg wen;                         // write enable
  reg [16:0] read_operations;      // number of read operations performed
  reg [16:0] write_operations;     // number of write operations performed
  reg error;                       // set an error flag on error
  reg [4:0] i;                     // loop variable

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  RegisterFile iDUT (.clk(clk), .rst(rst), .SrcReg1(stim[12:9]), .SrcReg2(stim[8:5]), .DstReg(stim[4:1]), .WriteReg(wen), .DstData(stim[28:13]), .SrcData1(src_data_1), .SrcData2(src_data_2));

  task automatic read_write_reg(
    input reg [3:0] reg_read1,   // First register to read from
    input reg [3:0] reg_read2,   // Second register to read from
    input reg [3:0] reg_write,   // Register to write to
    input reg [15:0] write_data, // Data to be written
    input reg enable_write       // Write enable signal
  );
    begin
      @(negedge clk);
      
      // Set the stimulus values
      wen = enable_write;       // Enable or disable write

      @(posedge clk);

      // Check slightly after positive edge of clock.
      #1;
      
      // If writing is enabled, update expected register file contents
      if (enable_write && reg_write !== 4'h0) begin
        regfile[reg_write] = write_data; // Write only if not register 0
      end

      // Verify read outputs with bypassing check
      if (reg_read1 === reg_write && enable_write) begin
        if (reg_read1 !== 4'h0) begin
          // Bypassing case: read register is same as write register
          if (src_data_1 !== write_data) begin
            $display("ERROR: Bypassing failed for SrcReg1[%d]. Expected 0x%h, got 0x%h", reg_read1, write_data, src_data_1);
            error = 1'b1;
          end
        end else begin
          // If register 0, should always be 0
          if (src_data_1 !== 16'h0000) begin
            $display("ERROR: Register 0 read failure for SrcReg1. Expected 0x0000, got 0x%h", src_data_1);
            error = 1'b1;
          end
        end
      end else begin
        // Normal read case: Check against register file contents
        if (reg_read1 !== 4'h0) begin
          if (src_data_1 !== regfile[reg_read1]) begin
            $display("ERROR: Reading from SrcReg1[%d] expected 0x%h, got 0x%h", reg_read1, regfile[reg_read1], src_data_1);
            error = 1'b1;
          end
        end else begin
          // If register 0, should always be 0
          if (src_data_1 !== 16'h0000) begin
            $display("ERROR: Register 0 read failure for SrcReg1. Expected 0x0000, got 0x%h", src_data_1);
            error = 1'b1;
          end
        end
      end

      // Verify read outputs with bypassing check
      if (reg_read2 === reg_write && enable_write) begin
        if (reg_read2 !== 4'h0) begin
          // Bypassing case: read register is same as write register
          if (src_data_2 !== write_data) begin
            $display("ERROR: Bypassing failed for SrcReg2[%d]. Expected 0x%h, got 0x%h", reg_read2, write_data, src_data_2);
            error = 1'b1;
          end
        end else begin
          // If register 0, should always be 0
          if (src_data_2 !== 16'h0000) begin
            $display("ERROR: Register 0 read failure for SrcReg2. Expected 0x0000, got 0x%h", src_data_2);
            error = 1'b1;
          end
        end
      end else begin
        // Normal read case: Check against register file contents
        if (reg_read2 !== 4'h0) begin
          if (src_data_2 !== regfile[reg_read2]) begin
            $display("ERROR: Reading from SrcReg2[%d] expected 0x%h, got 0x%h", reg_read2, regfile[reg_read2], src_data_2);
            error = 1'b1;
          end
        end else begin
          // If register 0, should always be 0
          if (src_data_2 !== 16'h0000) begin
            $display("ERROR: Register 0 read failure for SrcReg2. Expected 0x0000, got 0x%h", src_data_2);
            error = 1'b1;
          end
        end
      end

      // Count successful operations if no errors occurred
      if (!error) begin
        read_operations = read_operations + 1'b1;
        read_operations = read_operations + 1'b1;
        if (enable_write) write_operations = write_operations + 1'b1;
      end

      // Print error and stop simulation if any errors occurred
      if (error) begin
        $display("\nTotal operations performed: 0x%h.", read_operations + write_operations);
        $display("Number of Successful Reads Performed: 0x%h.", read_operations);
        $display("Number of Successful Writes Performed: 0x%h.", write_operations);
        $stop();
      end

      // Disable write
      @(negedge clk) wen = 1'b0;
    end
  endtask

  // Initialize the inputs and expected outputs and wait till all tests finish.
  initial begin
    clk = 1'b0; // initially clk is low
    rst = 1'b0; // initally rst is low
    i = 5'h0; // initialize loop variable
    wen = 1'b0; // initialize write enable
    stim = 28'h0000000; // initialize stimulus
    regfile = '{default: 16'h0000}; // initialize the register file
    read_operations = 17'h00000; // initialize read operation count
    write_operations = 17'h00000; // initialize write operation count
    error = 1'b0; // initialize error flag

    // Wait to initialize inputs.
    repeat(2) @(posedge clk);
    
    // Wait for a negative edge to assert rst.
    @(negedge clk) rst = 1'b1;

    // Wait for a full clock cycle before deasserting rst.
    @(negedge clk) rst = 1'b0;

    /* TEST CASE 1*/
    // Check that all registers have zero values initially.
    // Check all 16 register values, reading out of both bitlines. 
    for (i = 0; i < 5'h10; i = i + 1) begin
        // Set both source register ids.
        stim[12:9] = i[3:0];
        stim[8:5] = i[3:0];

        // Wait a while for each check.
        #1

        // Ensure both bitlines have the correct value. 
        read_write_reg(.reg_read1(stim[12:9]), .reg_read2(stim[8:5]), .reg_write(4'h0), .write_data(16'h0000), .enable_write(1'b0));
    end

    /* TEST CASE 2*/
    // Check that trying to write to register zero with a random value will have no effect.
    read_write_reg(.reg_read1(4'h0), .reg_read2(4'h0), .reg_write(4'h0), .write_data(16'h5678), .enable_write(1'b1));
    
    // Apply stimulus as 100000 random input vectors.
    repeat (100000) begin
      stim = $random & 28'hFFFFFFF; // Generate random stimulus

      // Wait to process the change in the input.
      #1;

      // Perform 2 reads and a write each clock cycle.
      read_write_reg(.reg_read1(stim[12:9]), .reg_read2(stim[8:5]), .reg_write(stim[4:1]), .write_data(stim[28:13]), .enable_write(stim[0]));
    end

    // Print out the number of oprations performed.
    $display("\nTotal operations performed: 0x%h.", read_operations + write_operations);
    $display("Number of Successful Reads Performed: 0x%h.", read_operations);
    $display("Number of Successful Writes Performed: 0x%h.", write_operations);      

    // If we reached here, it means that all tests passed.
    $display("YAHOO!! All tests passed.");
    $stop();
  end

always 
  #5 clk = ~clk; // toggle clock every 5 time units.
  
endmodule

`default_nettype wire  // Reset default behavior at the end