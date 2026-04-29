`timescale 1ns / 1ps
module top_equalizer (
    input wire clk,
    input wire rst_n,
    input wire sample_valid,
    input wire [15:0] sample_in,
    input wire [15:0] desired_in,
    input wire [7:0] desired_volume,
    output wire out_valid,
    output wire [15:0] sample_out
);


    wire        stage1_valid;
    wire [15:0] stage1_data;
    wire        stage2_valid;
    wire [15:0] stage2_data;
    wire        stage3_valid;
    wire [15:0] stage3_data;
    wire        stage4_valid;
    wire [15:0] stage4_data;
    wire        stage5_valid;
    wire [15:0] stage5_data;
    wire        stage6_valid;
    wire [15:0] stage6_data;
    wire        stage7_valid;
    wire [15:0] stage7_data;

    //start by removing white noise
    noise_filter #(
        .DATA_WIDTH(16),
        .TAP_COUNT (15)
    ) u_noise_filter (
        .clk         (clk),
        .rst_n       (rst_n),
        .in_valid    (sample_valid),
        .in_data     (sample_in),
        .out_valid   (stage1_valid),
        .out_data    (stage1_data)
    );
    //then remove uneccisary high or low frequency signals
    bandpass_filter #(
        .DATA_WIDTH (16),
        .COEFF_FILE ("bandpass_coeff.hex")
    ) u_bandpass (
        .clk         (clk),
        .rst_n       (rst_n),
        .in_valid    (stage1_valid),
        .in_data     (stage1_data),
        .out_valid   (stage2_valid),
        .out_data    (stage2_data)
    );
    //remove echo via adapative filter
    adaptive_equalizer #(
        .DATA_WIDTH(16),
        .TAP_COUNT(64)
    ) u_equalizer (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(stage2_valid),
        .distorted_in(stage2_data),
        .desired_in(desired_in),
        .out_valid(stage3_valid),
        .equalized_out(stage3_data)
    );
    //smooth out its output
    noise_filter #(
        .DATA_WIDTH(16),
        .TAP_COUNT (15)
    ) u_noise_filter_2 (
        .clk         (clk),
        .rst_n       (rst_n),
        .in_valid    (stage3_valid),
        .in_data     (stage3_data),
        .out_valid   (stage4_valid),
        .out_data    (stage4_data)
    );
    //average signal to reach consistant amplitude
    avg_agc #(
        .DATA_WIDTH   (16)
    ) u_agc_2 (
        .clk         (clk),
        .rst_n       (rst_n),
        .in_valid    (stage4_valid),
        .in_data     (stage4_data),
        .out_valid   (stage5_valid),
        .out_data    (stage5_data)
    );
    //remove peaks in signal
    flatten_agc #(
        .DATA_WIDTH   (16),
        .PEAK_THRESH  (16'd500)
    ) u_agc (
        .clk         (clk),
        .rst_n       (rst_n),
        .in_valid    (stage5_valid),
        .in_data     (stage5_data),
        .out_valid   (stage6_valid),
        .out_data    (stage6_data)
    );
    //clean out signal one more time
    noise_filter #(
        .DATA_WIDTH(16),
        .TAP_COUNT (15)
    ) u_noise_filter_3 (
        .clk         (clk),
        .rst_n       (rst_n),
        .in_valid    (stage6_valid),
        .in_data     (stage6_data),
        .out_valid   (stage7_valid),
        .out_data    (stage7_data)
    );
    //adjust the now clean signal's amplitude by volume
    volume_control #(
        .DATA_WIDTH(16)
    ) u_volume (
        .clk         (clk),
        .rst_n       (rst_n),
        .in_valid    (stage7_valid),
        .in_data     (stage7_data),
        .desired_volume(desired_volume),
        .out_valid   (out_valid),
        .out_data    (sample_out)
    );
endmodule