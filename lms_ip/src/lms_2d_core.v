`timescale 1ns / 1ps

module lms_2d_core #(
    parameter DATA_WIDTH = 8,
    parameter WEIGHT_W = 8,
    // 2u (use Shift Right instead of multiplier)
    parameter MU_SHIFT = 19 
)(
    input wire clk,
    input wire rst_n,

    // valid signal window
    input wire window_valid,

    // kernel
    input wire [DATA_WIDTH-1:0] p0, p1, p2,
    input wire [DATA_WIDTH-1:0] p3, p4, p5,
    input wire [DATA_WIDTH-1:0] p6, p7, p8,

    // desired signal
    input wire [DATA_WIDTH-1:0] d_in,

    // output pixel (center pixel)
    output wire [DATA_WIDTH-1:0] pixel_out
);

    // if window_valid = 0, then masked_p = 0 
    wire [DATA_WIDTH-1:0] masked_p [0:8];
    
    assign masked_p[0] = window_valid ? p0 : 8'd0;
    assign masked_p[1] = window_valid ? p1 : 8'd0;
    assign masked_p[2] = window_valid ? p2 : 8'd0;
    assign masked_p[3] = window_valid ? p3 : 8'd0;
    assign masked_p[4] = window_valid ? p4 : 8'd0;
    assign masked_p[5] = window_valid ? p5 : 8'd0;
    assign masked_p[6] = window_valid ? p6 : 8'd0;
    assign masked_p[7] = window_valid ? p7 : 8'd0;
    assign masked_p[8] = window_valid ? p8 : 8'd0;

    // weight array (signed 8-bit)
    reg signed [WEIGHT_W-1:0] weight [0:8];

    // Main Filter Process
    wire signed [DATA_WIDTH + WEIGHT_W-1:0] product [0:8];
    wire signed [19:0] mac_sum;

    genvar i;
    generate
        for (i = 0; i < 9; i = i + 1) begin : MAC_FILTER
            // Multiplier
            assign product[i] = $signed({1'b0, masked_p[i]}) * weight[i];
        end
    endgenerate

    // sum of products (MAC)
    assign mac_sum = product[0] + product[1] + product[2] +
                     product[3] + product[4] + product[5] +
                     product[6] + product[7] + product[8];

    // Q1.7 STANDARD: 1 bit for sign, 7 bits for fraction -> shift right 7 bits
    wire signed [19:0] mac_scaled = mac_sum >>> 7;

    assign pixel_out = (mac_scaled < 0)   ? 8'd0 :
                       (mac_scaled > 255) ? 8'd255 :
                       mac_scaled[7:0];

    // SUBTRACTOR d [7:0] - pixel_out [7:0] -> Error (e)
    wire signed [DATA_WIDTH:0] error;
    assign error = $signed({1'b0, d_in}) - $signed({1'b0, pixel_out});

    // Weight Update
    // w_next = w + 2u * e * x
    // shift right MU_SHIFT bits instead of multiply by 2u
    // wire signed [DATA_WIDTH:0] error_2u;
    // assign error_2u = error >>> MU_SHIFT; 

    wire signed [WEIGHT_W-1:0] next_weight [0:8];

    generate
        for (i = 0; i < 9; i = i + 1) begin : UPDATE_PATH
            wire signed [17:0] gradient;
            assign gradient = error * $signed({1'b0, masked_p[i]});

            wire signed [17:0] gradient_scaled;
            assign gradient_scaled = gradient >>> (MU_SHIFT - 7);
            
            wire signed [17:0] temp_weight;
            assign temp_weight = weight[i] + gradient_scaled;
            
            assign next_weight[i] = (temp_weight > 127)  ? 8'h7F :
                                    (temp_weight < -128) ? 8'h80 :
                                    temp_weight[7:0];
        end
    endgenerate

    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 0; j < 9; j = j + 1) begin        
                    weight[j] <= 8'd0; 
            end
        end else begin
            if (window_valid) begin
                for (j = 0; j < 9; j = j + 1) begin
                    weight[j] <= next_weight[j];
                end
            end
        end
    end

endmodule