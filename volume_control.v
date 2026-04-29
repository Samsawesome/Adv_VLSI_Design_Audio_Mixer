module volume_control #(
    parameter DATA_WIDTH = 16
) (
    input wire clk, 
    input wire rst_n,
    input wire in_valid,
    input wire signed [DATA_WIDTH-1:0] in_data,
    input wire [7:0] desired_volume,
    output reg out_valid,
    output reg signed [DATA_WIDTH-1:0] out_data
);
    // Use only the lower VOLUME_BITS bits, limit to 2^VOLUME_BITS
    wire signed [7:0] volume_scaled;
    //ensure no volume overflow
    assign volume_scaled = (desired_volume > (2**7)) ? (2**7) : desired_volume[6:0];

    reg signed [31:0] product;

    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            out_valid <= 0;
            out_data  <= 0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                product = in_data * volume_scaled;
                out_data <= product >>> 3; //can change this number to adjust volume change
            end
        end
    end
endmodule