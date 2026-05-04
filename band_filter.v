module bandpass_filter #(
    parameter DATA_WIDTH = 16,
    parameter TAPS       = 64,
    parameter COEFF_FILE = "Data/bandpass_coeff.hex"
) (
    input wire clk, 
    input wire reset,
    input wire in_valid,
    input wire [DATA_WIDTH-1:0] in_data,
    output reg out_valid,
    output reg  [DATA_WIDTH-1:0] out_data
);

    reg signed [DATA_WIDTH-1:0] coeff [0:TAPS-1];
    reg signed [DATA_WIDTH-1:0] delay_line [0:TAPS-1];
    reg [$clog2(TAPS):0] valid_cnt; //dynamic declaration w clog2
    integer i;
    reg signed [2*DATA_WIDTH+$clog2(TAPS)-1:0] acc; //same

    initial begin
        $readmemh(COEFF_FILE, coeff);
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < TAPS; i = i+1) 
                delay_line[i] <= 0;
            valid_cnt <= 0;
            out_valid <= 1'b0;
            out_data  <= 0;
        end else begin
            out_valid <= 1'b0;//default no output (if not valid yet)
            if (in_valid) begin
                //shift array and add new sample
                for (i = TAPS-1; i > 0; i = i-1)
                    delay_line[i] <= delay_line[i-1];
                delay_line[0] <= in_data;

                //need to fill array before it can be used
                if (valid_cnt < TAPS)
                    valid_cnt <= valid_cnt + 1;
                else begin
                    //apply FIR filter
                    acc = 0;
                    for (i = 0; i < TAPS; i = i+1)
                        acc = acc + delay_line[i] * coeff[i];
                    out_data  <= acc >>> (DATA_WIDTH-1);
                    out_valid <= 1'b1;
                end
            end
        end
    end
endmodule
