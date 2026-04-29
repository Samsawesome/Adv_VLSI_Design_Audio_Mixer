/*// File: gain_control.v
module flatten_agc #(
    parameter DATA_WIDTH   = 16,
    parameter TAPS         = 64,
    parameter TARGET_LEVEL = 16'h2000,      // 8192
    parameter GAIN_SMOOTH  = 1,
    parameter SMOOTH_BITS  = 4,             // 1/16 smoothing
    parameter PEAK_THRESH  = 16'd22000,     // ceiling for limiter
    parameter RELEASE_SHIFT = 5             // release speed (1/32 per sample)
) (
    input  wire                 clk, rst_n,
    input  wire                 in_valid,
    input  wire signed [DATA_WIDTH-1:0] in_data,
    output reg                  out_valid,
    output reg  signed [DATA_WIDTH-1:0] out_data
);

    // -------- AGC envelope & gain (unchanged) --------
    reg signed [DATA_WIDTH-1:0] delay_line [0:TAPS-1];
    reg [$clog2(TAPS)+DATA_WIDTH:0] sum_abs;
    reg [$clog2(TAPS):0] valid_cnt;
    reg signed [15:0] gain;                     // Q8.8 (1.0 = 256)
    reg signed [31:0] target_gain_q24;
    integer i;

    function [DATA_WIDTH:0] abs_val;
        input signed [DATA_WIDTH-1:0] val;
        reg signed [DATA_WIDTH:0] ext;
        begin
            ext = val;
            abs_val = (ext < 0) ? -ext : ext;
        end
    endfunction

    // -------- Peak limiter state --------
    reg signed [15:0] limit_reduction;          // Q8.8 gain reduction (256 = no reduction)
    reg signed [31:0] raw_output;               // full‑width AGC output before limiter

    reg signed [31:0] product;
    reg signed [31:0] inst_reduction;
    reg signed [31:0] limited_product;
    reg signed [31:0] limited;

    reg [DATA_WIDTH:0] abs_raw;

    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            for (i = 0; i < TAPS; i = i+1) delay_line[i] <= 0;
            valid_cnt <= 0;
            gain      <= 16'h0100;
            limit_reduction <= 16'h0100;        // 1.0, no reduction
            out_valid <= 1'b0;
            out_data  <= 0;
        end else begin
            out_valid <= in_valid;

            if (in_valid) begin
                // Shift
                for (i = TAPS-1; i > 0; i = i-1)
                    delay_line[i] <= delay_line[i-1];
                delay_line[0] <= in_data;

                if (valid_cnt < TAPS) begin
                    valid_cnt <= valid_cnt + 1;
                    out_data  <= in_data;       // feed through while buffer fills
                end else begin
                    // ----- AGC envelope -----
                    sum_abs = 0;
                    for (i = 0; i < TAPS; i = i+1)
                        sum_abs = sum_abs + abs_val(delay_line[i]);

                    if (sum_abs == 0)
                        target_gain_q24 = 32'h000100;
                    else
                        target_gain_q24 = ($signed(TARGET_LEVEL) * 256 * TAPS) / sum_abs;

                    if (GAIN_SMOOTH)
                        gain <= gain + ((target_gain_q24 - gain) >>> SMOOTH_BITS);
                    else
                        gain <= target_gain_q24;

                    // ----- Apply AGC gain (full 32‑bit) -----
                    
                    product = $signed(in_data) * $signed(gain);
                    raw_output = product >>> 8;          // Q16.0

                    // ----- Peak limiter -----
                    // 1. Compute instantaneous reduction needed to keep this sample below threshold.
                    //    desired_gain_for_this_sample = PEAK_THRESH / |raw_output| (in Q8.8)
                    
                    if (raw_output < 0)
                        abs_raw = -raw_output;
                    else
                        abs_raw = raw_output;

                    
                    if (abs_raw > PEAK_THRESH) begin
                        // inst_reduction = (PEAK_THRESH << 8) / abs_raw
                        inst_reduction = ($signed(PEAK_THRESH) * 256) / $signed({1'b0, abs_raw});
                    end else begin
                        inst_reduction = 16'h0100;   // no reduction needed
                    end

                    // 2. Update limiter gain: fast attack (immediate) if needed,
                    //    slow release (add a small amount towards 256 each sample)
                    if (inst_reduction < limit_reduction)
                        limit_reduction <= inst_reduction;                // instant attack
                    else if (limit_reduction < 16'h0100)
                        limit_reduction <= limit_reduction + ( (16'h0100 - limit_reduction) >>> RELEASE_SHIFT );
                    // else stays at 256 (no limiting active)

                    // 3. Apply limiter reduction to raw_output
                    
                    limited_product = raw_output * $signed(limit_reduction);
                    
                    limited = limited_product >>> 8;   // back to Q16.0

                    // 4. Final saturation to 16‑bit (paranoid, but safe)
                    if (limited > 32767)
                        out_data <= 16'd32767;
                    else if (limited < -32768)
                        out_data <= -16'd32768;
                    else
                        out_data <= limited;
                end
            end
        end
    end
endmodule*/


//this agc focuses more on remove peaks in the signal
module flatten_agc #(
    parameter DATA_WIDTH = 16,
    parameter TAPS = 64,
    parameter TARGET_LEVEL = 16'h2000,
    parameter SMOOTH_BITS = 4,
    parameter PEAK_THRESH = 16'd22000,
    parameter RELEASE_SHIFT = 5
) (
    input wire clk, 
    input wire rst_n,
    input wire in_valid,
    input wire signed [DATA_WIDTH-1:0] in_data,
    output reg out_valid,
    output reg signed [DATA_WIDTH-1:0] out_data
);

    reg signed [DATA_WIDTH-1:0] delay_line [0:TAPS-1];
    reg [$clog2(TAPS)+DATA_WIDTH:0] sum_abs;
    reg [$clog2(TAPS):0] valid_cnt;
    reg signed [15:0] gain;
    reg signed [31:0] target_gain_q24;
    integer i;


    // -------- Peak limiter state --------
    reg signed [15:0] limit_reduction;          // Q8.8 gain reduction (256 = no reduction)
    reg signed [31:0] raw_output;               // full‑width AGC output before limiter

    reg signed [31:0] product;
    reg signed [31:0] inst_reduction;
    reg signed [31:0] limited_product;
    reg signed [31:0] limited;

    reg [DATA_WIDTH:0] abs_raw;
    reg signed [DATA_WIDTH-1:0] abs_delay_line;

    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            for (i = 0; i < TAPS; i = i+1) delay_line[i] <= 0;
            valid_cnt <= 0;
            gain      <= 16'h0100;
            limit_reduction <= 16'h0100;        // 1.0, no reduction
            out_valid <= 1'b0;
            out_data  <= 0;
            abs_raw <= 0;
            abs_delay_line <=0;
            product <= 0;
            inst_reduction <= 0;
            limited_product <= 0;
            limited <= 0;
            raw_output <= 0;
        end else begin
            out_valid <= in_valid;

            if (in_valid) begin
                // Shift
                for (i = TAPS-1; i > 0; i = i-1)
                    delay_line[i] <= delay_line[i-1];
                delay_line[0] <= in_data;

                if (valid_cnt < TAPS) begin
                    valid_cnt <= valid_cnt + 1;
                    out_data  <= in_data; //feed through to not have even more delay
                end else begin
                    //sum abs of all signals
                    sum_abs = 0;
                    for (i = 0; i < TAPS; i = i+1) begin
                        abs_delay_line = (delay_line[i] < 0) ? -delay_line[i] : delay_line[i];
                        sum_abs = sum_abs + abs_delay_line;
                    end 
                    //calculate target gain based on sum and target_level
                    if (sum_abs == 0)
                        target_gain_q24 = 32'h000100;
                    else
                        target_gain_q24 = ($signed(TARGET_LEVEL) * 256 * TAPS) / sum_abs;

                    //smooth gain
                    gain <= gain + ((target_gain_q24 - gain) >>> SMOOTH_BITS);
                   

                    //apply gain
                    product = $signed(in_data) * $signed(gain);
                    raw_output = product >>> 8;//keep it 16 bits

                    if (raw_output < 0)
                        abs_raw = -raw_output;
                    else
                        abs_raw = raw_output;

                    //if too large, force to be smaller
                    if (abs_raw > PEAK_THRESH) begin
                        inst_reduction = ($signed(PEAK_THRESH) * 256) / $signed({1'b0, abs_raw});
                    end else begin
                        inst_reduction = 16'h0100;   // no reduction needed
                    end

                    //update peak reduction
                    if (inst_reduction < limit_reduction)
                        limit_reduction <= inst_reduction;
                    else if (limit_reduction < 16'h0100)
                        limit_reduction <= limit_reduction + ( (16'h0100 - limit_reduction) >>> RELEASE_SHIFT );

                   //apply limits
                    limited_product = raw_output * $signed(limit_reduction);
                    limited = limited_product >>> 8;//16 bit

                    //ensure no overflow
                    if (limited > 32767)
                        out_data <= 16'd32767;
                    else if (limited < -32768)
                        out_data <= -16'd32768;
                    else
                        out_data <= limited;
                end
            end
        end
    end
endmodule
