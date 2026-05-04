module noise_filter #(
    parameter DATA_WIDTH = 16,
    parameter TAP_COUNT  = 15
) (
    input wire clk, 
    input wire reset,
    input wire in_valid,
    input wire signed [DATA_WIDTH-1:0] in_data,
    output reg out_valid,
    output reg signed [DATA_WIDTH-1:0] out_data
);

    //dynamic declarations
    reg signed [DATA_WIDTH-1:0] shift_reg [0:TAP_COUNT-1];
    reg signed [DATA_WIDTH*2-1:0] summer;
    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < TAP_COUNT; i = i+1)
                shift_reg[i] <= 0;
            summer <= 0;
            out_valid <= 1'b0;
            out_data  <= 0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                //shift array
                for (i = TAP_COUNT-1; i > 0; i = i-1)
                    shift_reg[i] <= shift_reg[i-1];
                shift_reg[0] <= in_data;
                summer = 0;
                //sum
                for (i = 0; i < TAP_COUNT; i = i + 1)
                    summer = summer + shift_reg[i];
                //average
                out_data <= summer / TAP_COUNT;
            end
        end
    end
endmodule
