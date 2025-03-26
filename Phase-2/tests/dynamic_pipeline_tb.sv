module dynamic_pipeline_tb();
   // Instantiate the pipeline module
    dynamic_pipeline uut();

    // Testbench Control
    initial begin
        // $dumpfile("pipeline_tb.vcd"); // For waveform debugging
        // $dumpvars(0, dynamic_pipeline_tb);

        $display("Starting Pipeline Simulation...");
        #200; // Run simulation for 200 time units
        $display("Simulation Completed.");
        $finish;
    end
endmodule