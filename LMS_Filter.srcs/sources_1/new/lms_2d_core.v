`timescale 1ns / 1ps
// ============================================================================
// lms_2d_core.v - LMS 2D 3x3, so hoc fixed-point khop voi lms_golden.py
//   Trong so: signed WEIGHT_W bit, FRAC bit phan le (mac dinh Q6.18)
//   y   = sat_0_255( round( sum(w_i * x_i) / 2^FRAC ) )
//   e   = d - y
//   w  += round( e * x_i / 2^SHIFT )   voi SHIFT = MU_LOG2 + 15 - FRAC
//   => tuong duong Python (anh chuan hoa /255):  W += 2*mu*e*x,  mu = 2^-MU_LOG2
//      (xap xi 255*255 ~ 2^16, sai khac 0.8%)
// ============================================================================
module lms_2d_core #(
    parameter DATA_WIDTH = 8,
    parameter WEIGHT_W   = 24,
    parameter FRAC       = 18,
    parameter MU_LOG2    = 5        // mu = 2^-5 (Python: MU = 2**-5)
)(
    input  wire clk,
    input  wire rst_n,
    input  wire update_en,          // cap nhat trong so (1 lan / cua so hop le)
    input  wire wreset,             // dua trong so ve gia tri khoi tao
    input  wire [DATA_WIDTH-1:0] p0, p1, p2, p3, p4, p5, p6, p7, p8,
    input  wire [DATA_WIDTH-1:0] d_in,
    output wire [DATA_WIDTH-1:0] pixel_out
);
    localparam SHIFT  = MU_LOG2 + 15 - FRAC;
    localparam ACC_W  = WEIGHT_W + DATA_WIDTH + 1 + 4;   // 9 tich -> +4 bit
    localparam GRAD_W = 2*DATA_WIDTH + 2;
    localparam signed [WEIGHT_W-1:0] W_MAX = {1'b0, {(WEIGHT_W-1){1'b1}}};
    localparam signed [WEIGHT_W-1:0] W_MIN = {1'b1, {(WEIGHT_W-1){1'b0}}};
    localparam signed [WEIGHT_W-1:0] W_ONE = (1 <<< FRAC);

    wire [DATA_WIDTH-1:0] x [0:8];
    assign x[0]=p0; assign x[1]=p1; assign x[2]=p2;
    assign x[3]=p3; assign x[4]=p4; assign x[5]=p5;
    assign x[6]=p6; assign x[7]=p7; assign x[8]=p8;

    reg signed [WEIGHT_W-1:0] weight [0:8];

    // ---------------- Loc: y = W^T X ----------------
    wire signed [ACC_W-1:0] product [0:8];
    genvar i;
    generate
        for (i = 0; i < 9; i = i + 1) begin : MAC
            assign product[i] = weight[i] * $signed({1'b0, x[i]});
        end
    endgenerate

    wire signed [ACC_W-1:0] mac_sum = product[0] + product[1] + product[2]
                                    + product[3] + product[4] + product[5]
                                    + product[6] + product[7] + product[8];
    // lam tron ve gan nhat roi bo FRAC bit
    wire signed [ACC_W-1:0] mac_rnd = (mac_sum + (1 <<< (FRAC-1))) >>> FRAC;

    assign pixel_out = (mac_rnd < 0)   ? {DATA_WIDTH{1'b0}} :
                       (mac_rnd > 255) ? {DATA_WIDTH{1'b1}} :
                                         mac_rnd[DATA_WIDTH-1:0];

    // ---------------- Sai so ----------------
    wire signed [DATA_WIDTH+1:0] error = $signed({2'b00, d_in}) - $signed({2'b00, pixel_out});

    // ---------------- Cap nhat trong so ----------------
    wire signed [WEIGHT_W-1:0] next_weight [0:8];
    generate
        for (i = 0; i < 9; i = i + 1) begin : UPD
            wire signed [GRAD_W-1:0]  grad  = error * $signed({1'b0, x[i]});
            wire signed [GRAD_W-1:0]  delta;
            if (SHIFT > 0) begin : RND
                assign delta = (grad + (1 <<< (SHIFT-1))) >>> SHIFT;   // lam tron, tranh lech am
            end else begin : NORND
                assign delta = grad <<< (-SHIFT);
            end
            wire signed [WEIGHT_W:0] sum = weight[i] + delta;
            assign next_weight[i] = (sum > W_MAX) ? W_MAX :
                                    (sum < W_MIN) ? W_MIN : sum[WEIGHT_W-1:0];
        end
    endgenerate

    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 0; j < 9; j = j + 1) weight[j] <= (j == 4) ? W_ONE : 0;
        end else if (wreset) begin
            for (j = 0; j < 9; j = j + 1) weight[j] <= (j == 4) ? W_ONE : 0;
        end else if (update_en) begin
            for (j = 0; j < 9; j = j + 1) weight[j] <= next_weight[j];
        end
    end
endmodule