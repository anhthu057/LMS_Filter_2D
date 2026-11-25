`timescale 1ns / 1ps
// ============================================================================
// lms_2d_top.v - kernel + core + thanh ghi dau ra voi handshake valid/ready
//   Dau vao 256x256 -> dau ra 254x254 (bo vien), out_user = pixel dau,
//   out_last = pixel cuoi frame (bat buoc de AXI DMA S2MM ket thuc).
// ============================================================================
module lms_2d_top #(
    parameter IMG_WIDTH  = 256,
    parameter IMG_HEIGHT = 256,
    parameter DATA_WIDTH = 8,
    parameter WEIGHT_W   = 24,
    parameter FRAC       = 18,
    parameter MU_LOG2    = 5,
    parameter RESET_W_PER_FRAME = 1   // 1: moi anh bat dau tu W khoi tao (giong Python)
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  in_valid,   // ca noisy lan clean deu hop le
    output wire                  in_ready,
    input  wire [DATA_WIDTH-1:0] pixel_in,
    input  wire [DATA_WIDTH-1:0] d_in,
    input  wire                  in_last,

    output reg  [DATA_WIDTH-1:0] out_data,
    output reg                   out_valid,
    input  wire                  out_ready,
    output reg                   out_last,
    output reg                   out_user
);
    wire [DATA_WIDTH-1:0] p0, p1, p2, p3, p4, p5, p6, p7, p8, d_c, y;
    wire win_valid, win_sof, win_eof, frame_start;

    // commit: cua so hop le + thanh ghi ra trong (hoac dang duoc doc)
    wire commit     = win_valid && (!out_valid || out_ready);
    wire can_accept = !win_valid || commit;
    wire fire       = in_valid && can_accept;
    assign in_ready = can_accept;

    kernel #(.IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT), .DATA_WIDTH(DATA_WIDTH)) u_kernel (
        .clk(clk), .rst_n(rst_n), .shift_en(fire), .consume(commit),
        .pixel_in(pixel_in), .d_in(d_in), .pixel_last(in_last),
        .w00(p0), .w01(p1), .w02(p2),
        .w10(p3), .w11(p4), .w12(p5),
        .w20(p6), .w21(p7), .w22(p8),
        .d_center(d_c), .window_valid(win_valid),
        .window_sof(win_sof), .window_eof(win_eof), .frame_start(frame_start));

    lms_2d_core #(.DATA_WIDTH(DATA_WIDTH), .WEIGHT_W(WEIGHT_W), .FRAC(FRAC), .MU_LOG2(MU_LOG2)) u_core (
        .clk(clk), .rst_n(rst_n), .update_en(commit),
        .wreset((RESET_W_PER_FRAME != 0) && fire && frame_start),
        .p0(p0), .p1(p1), .p2(p2), .p3(p3), .p4(p4), .p5(p5), .p6(p6), .p7(p7), .p8(p8),
        .d_in(d_c), .pixel_out(y));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0; out_data <= 0; out_last <= 1'b0; out_user <= 1'b0;
        end else if (commit) begin
            out_valid <= 1'b1; out_data <= y; out_last <= win_eof; out_user <= win_sof;
        end else if (out_ready) begin
            out_valid <= 1'b0;
        end
    end
endmodule