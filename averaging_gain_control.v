//this agc focuses more on averaging the signal aka keeping it a constant amplitude
module avg_agc #(
    parameter DATA_WIDTH   = 16,
    parameter TARGET_RMS   = 16'd2048,
    parameter RMS_ATTACK   = 7,
    parameter RMS_RELEASE  = 8,
    parameter MS_SMOOTH    = 2,
    parameter PEAK_THRESH  = 16'd2000, //clips for consistant amplitude
    parameter LIMIT_RELEASE= 7
) (
    input wire clk, 
    input wire reset,
    input wire in_valid,
    input wire signed [DATA_WIDTH-1:0] in_data,
    output reg out_valid,
    output reg signed [DATA_WIDTH-1:0] out_data
);

    reg [47:0] ms_q;
    reg [15:0] rms;
    reg [23:0] rms_corrected;
    reg [31:0] target_gain_q24;
    reg signed [15:0] gain;
    reg signed [15:0] limit_reduction;

    reg [31:0] sq;
    reg signed [31:0] product, raw_output, diff;
    reg signed [31:0] abs_raw, inst_reduction, limited_product, limited;

    function [15:0] sqrt32;
        input [31:0] x;
        reg [31:0] rem, root;
        integer i;
        begin
            rem = 0; root = 0;
            for (i = 0; i < 16; i = i + 1) begin
                root = {root[30:0], 1'b1};
                rem  = {rem[29:0], x[31:30]};
                x    = {x[29:0], 2'b00};
                if (root <= rem) begin
                    rem = rem - root;
                    root[0] = 1'b1;
                end else
                    root[0] = 1'b0;
            end
            sqrt32 = root[15:0];
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ms_q <= 0;
            rms <= 0;
            rms_corrected <= 0;
            gain <= 16'h0100;
            limit_reduction <= 16'h0100;
            out_valid <= 0;
            out_data <= 0;
        end else begin
            out_valid <= in_valid;

            if (in_valid) begin
                //mean square
                sq = in_data * in_data;
                if (ms_q == 0)
                    ms_q <= {15'd0, sq};
                else
                    ms_q <= ms_q + ($signed({16'd0, sq} - ms_q) >>> MS_SMOOTH);

                //rms from mean square
                rms <= sqrt32(ms_q[47:16]);

                //rms scaled correctly
                rms_corrected = rms * 256;
                if (rms == 0)
                    target_gain_q24 = 32'h000100;
                else
                    target_gain_q24 = ($signed(TARGET_RMS) * 256) / rms_corrected;

                //adjust gain via rms attack and release
                diff = target_gain_q24 - gain;
                if (diff < 0)
                    gain <= gain + (diff >>> RMS_ATTACK);
                else
                    gain <= gain + (diff >>> RMS_RELEASE);

                //make sure gain cant be zero, min is 0.0625
                if (gain < 16'h0010) gain <= 16'h0010;

                product    = $signed(in_data) * $signed(gain);
                raw_output = product >>> 8; //scale down into 16 bit

                //remove peaks
                if (raw_output < 0)
                    abs_raw = -raw_output;
                else
                    abs_raw = raw_output;

                if (abs_raw > PEAK_THRESH)
                    inst_reduction = ($signed(PEAK_THRESH) * 256) / abs_raw;
                else
                    inst_reduction = 16'h0100;

                if (inst_reduction < limit_reduction)
                    limit_reduction <= inst_reduction;
                else if (limit_reduction < 16'h0100)
                    limit_reduction <= limit_reduction + ((16'h0100 - limit_reduction) >>> LIMIT_RELEASE);

                limited_product = raw_output * $signed(limit_reduction);
                limited = limited_product >>> 5; //scale down again into 16 bit

                //Ensure no overflow
                if (limited > 32767)
                    out_data <= 16'd32767;
                else if (limited < -32768)
                    out_data <= -16'd32768;
                else
                    out_data <= limited;
            end
        end
    end
endmodule
