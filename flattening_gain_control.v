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
    input wire reset,
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

    always @(posedge clk or posedge reset) begin
        if (reset) begin
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
