`timescale 1ns / 1ps
module tb_top_equalizer;
    reg clk;
    reg reset;
    reg sample_valid;
    reg [15:0] sample_in;
    reg [15:0] desired_in;
    wire out_valid;
    wire [15:0] sample_out;

    integer infile, outfile, referencefile, in_scan_result, ref_scan_result;
    reg [15:0] in_hex_val;
    reg [15:0] ref_hex_val;
    integer sample_count, out_count, last_report;

    reg [7:0] desired_volume = 100;

    top_equalizer dut (
        .clk          (clk),
        .reset        (reset),
        .sample_valid (sample_valid),
        .sample_in    (sample_in),
        .desired_in(desired_in),
        .desired_volume(desired_volume),
        .out_valid    (out_valid),
        .sample_out   (sample_out)
    );

    //~48kHz to match sample frequency
    always #10417 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        sample_valid = 0;
        sample_in = 0;
        sample_count = 0;
        out_count = 0;
        last_report = 0;

        infile = $fopen("Data/input.hex", "r");
        if (infile == 0) begin
            $display("ERROR: input.hex not found");
            $finish;
        end

        referencefile = $fopen("Data/reference_input.hex", "r");
        if (referencefile == 0) begin
            $display("ERROR: reference.hex not found");
            $finish;
        end

        outfile = $fopen("Data/output.hex", "w");
        if (outfile == 0) begin
            $display("ERROR: cannot create output.hex");
            $finish;
        end

        #100 reset = 0;
        @(posedge clk);

        $display("=== Starting simulation ===");

        // Feed samples
        while (!$feof(infile) && !$feof(referencefile)) begin
            in_scan_result = $fscanf(infile, "%h\n", in_hex_val);
            ref_scan_result = $fscanf(referencefile, "%h\n", ref_hex_val);
            if (in_scan_result == 1 && ref_scan_result == 1) begin
                @(posedge clk);
                sample_valid <= 1;
                sample_in    <= in_hex_val;
                desired_in    <= ref_hex_val;
                sample_count = sample_count + 1;
                //ensure process is running
                if (sample_count % 10000 == 0)
                    $display("[%0t] Fed %0d samples", $time, sample_count);
                @(posedge clk);
                sample_valid <= 0;
            end else begin
                $fscanf(infile, "%s", 0);
                $fscanf(referencefile, "%s", 0);
            end
        end

        $display("[%0t] All %0d samples fed. Flushing pipeline...", $time, sample_count);

        //wait for pipeline to be empty
        //~41 ms wait
        repeat(2000) @(posedge clk);

        $fclose(infile);
        $fclose(outfile);
        $fclose(referencefile);
        $display("=== Simulation finished ===");
        $display("Input samples  : %0d", sample_count);
        $display("Output samples : %0d", out_count);
        $finish;
    end

    //write outputs when valid
    always @(posedge clk) begin
        if (out_valid) begin
            out_count = out_count + 1;
            $fwrite(outfile, "%h\n", sample_out);
        end
    end

endmodule