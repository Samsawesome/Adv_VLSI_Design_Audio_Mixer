module adaptive_equalizer #(
    parameter DATA_WIDTH = 16,
    parameter TAP_COUNT = 64,
    parameter STEP = 2
)(
    input  wire clk, reset,
    input  wire in_valid,
    input  wire signed [DATA_WIDTH-1:0] distorted_in,
    input  wire signed [DATA_WIDTH-1:0] desired_in,
    output reg  out_valid,
    output reg  signed [DATA_WIDTH-1:0] equalized_out
);

    reg signed [DATA_WIDTH-1:0] coeffs [0:TAP_COUNT-1];
    reg signed [DATA_WIDTH-1:0] delay [0:TAP_COUNT-1];
    reg signed [31:0] filtered;
    reg signed [DATA_WIDTH-1:0] error;
    integer i;
    reg signed [31:0] update;

    // FIR filter
    reg signed [31:0] acc;
    always @(*) begin
        acc = 0;
        for (i = 0; i < TAP_COUNT; i = i+1)
            acc = acc + (coeffs[i] * delay[i]);
        filtered = acc;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < TAP_COUNT; i = i+1) coeffs[i] <= 0;
            for (i = 0; i < TAP_COUNT; i = i+1) delay[i] <= 0;
            out_valid <= 0;
            equalized_out <= 0;
            error <= 0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                // Shift delay line
                for (i = TAP_COUNT-1; i > 0; i = i-1)
                    delay[i] <= delay[i-1];
                delay[0] <= distorted_in;

                // Output: scale filtered from Q8.8 to 16-bit
                equalized_out <= filtered >>> 8;
                error = desired_in - (filtered >>> 8);

                // Sign-error LMS update (very stable)
                for (i = 0; i < TAP_COUNT; i = i+1) begin
                    // update = sign(error) * delay[i] >> (STEP_SHIFT + 8)
                    if (error >= 0) begin
                        update = (delay[i] >= 0) ? STEP : -STEP;
                    end else begin
                        update = (delay[i] >= 0) ? -STEP : STEP;
                    end
                    // Coefficient update with saturation to ±256
                    if (coeffs[i] + update > 256)
                        coeffs[i] <= 256;
                    else if (coeffs[i] + update < -256)
                        coeffs[i] <= -256;
                    else
                        coeffs[i] <= coeffs[i] + update;
                end
            end
        end
    end
endmodule