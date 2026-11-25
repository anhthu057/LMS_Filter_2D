`timescale 1ns / 1ps
// ============================================================================
// kernel.v - Tao cua so 3x3 + can chinh tin hieu mong muon d (anh sach)
//   * shift_en : nhan 1 pixel moi (noisy + clean) - chi dich khi co handshake
//   * consume  : top bao cua so hien tai da duoc xu ly xong
//   * d_center : pixel SACH tai DUNG tam cua so (tre IMG_WIDTH+1 pixel)
//   * Bo dem x/y quay ve 0 sau IMG_HEIGHT hang, hoac khi gap pixel_last (TLAST)
// ============================================================================
module kernel #(
    parameter IMG_WIDTH  = 256,
    parameter IMG_HEIGHT = 256,
    parameter DATA_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  shift_en,
    input  wire                  consume,
    input  wire [DATA_WIDTH-1:0] pixel_in,   // anh nhieu x
    input  wire [DATA_WIDTH-1:0] d_in,       // anh sach d (cung vi tri voi pixel_in)
    input  wire                  pixel_last, // TLAST cua pixel cuoi frame

    output reg  [DATA_WIDTH-1:0] w00, w01, w02,
    output reg  [DATA_WIDTH-1:0] w10, w11, w12,
    output reg  [DATA_WIDTH-1:0] w20, w21, w22,
    output reg  [DATA_WIDTH-1:0] d_center,
    output reg                   window_valid, // cua so hop le dang cho xu ly
    output reg                   window_sof,   // cua so dau tien cua frame
    output reg                   window_eof,   // cua so cuoi cung cua frame
    output wire                  frame_start   // pixel sap vao la pixel (0,0)
);
    localparam XW = $clog2(IMG_WIDTH);
    localparam YW = $clog2(IMG_HEIGHT);

    reg [DATA_WIDTH-1:0] line_buffer_1 [0:IMG_WIDTH-1];
    reg [DATA_WIDTH-1:0] line_buffer_2 [0:IMG_WIDTH-1];
    reg [DATA_WIDTH-1:0] d_line_buf    [0:IMG_WIDTH-1];
    reg [DATA_WIDTH-1:0] d_d1;

    reg [XW-1:0] x_cnt;   // cot cua pixel SAP vao (dung luon lam con tro line buffer)
    reg [YW-1:0] y_cnt;

    wire [DATA_WIDTH-1:0] pop_lb1 = line_buffer_1[x_cnt];
    wire [DATA_WIDTH-1:0] pop_lb2 = line_buffer_2[x_cnt];
    wire [DATA_WIDTH-1:0] pop_d   = d_line_buf[x_cnt];

    assign frame_start = (x_cnt == 0) && (y_cnt == 0);

    // Line buffer: khong reset (de Vivado suy ra LUTRAM/BRAM)
    always @(posedge clk) begin
        if (shift_en) begin
            line_buffer_1[x_cnt] <= pixel_in;
            line_buffer_2[x_cnt] <= pop_lb1;
            d_line_buf[x_cnt]    <= d_in;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 0; y_cnt <= 0;
            w00 <= 0; w01 <= 0; w02 <= 0;
            w10 <= 0; w11 <= 0; w12 <= 0;
            w20 <= 0; w21 <= 0; w22 <= 0;
            d_d1 <= 0; d_center <= 0;
            window_valid <= 1'b0; window_sof <= 1'b0; window_eof <= 1'b0;
        end else if (shift_en) begin
            // Dich cua so 3x3 (cot trai <- cot giua <- cot phai <- du lieu moi)
            w00 <= w01; w10 <= w11; w20 <= w21;
            w01 <= w02; w11 <= w12; w21 <= w22;
            w02 <= pop_lb2; w12 <= pop_lb1; w22 <= pixel_in;

            // Tam cua so = pixel vao truoc pixel moi nhat (IMG_WIDTH+1) nhip
            d_d1     <= pop_d;   // clean[k - W]
            d_center <= d_d1;    // clean[k - W - 1]  == tam cua so

            window_valid <= (x_cnt >= 2) && (y_cnt >= 2);
            window_sof   <= (x_cnt == 2) && (y_cnt == 2);
            window_eof   <= (x_cnt == IMG_WIDTH-1) && (y_cnt == IMG_HEIGHT-1);

            if (pixel_last || ((x_cnt == IMG_WIDTH-1) && (y_cnt == IMG_HEIGHT-1))) begin
                x_cnt <= 0; y_cnt <= 0;              // het frame -> ve dau
            end else if (x_cnt == IMG_WIDTH-1) begin
                x_cnt <= 0; y_cnt <= y_cnt + 1'b1;
            end else begin
                x_cnt <= x_cnt + 1'b1;
            end
        end else if (consume) begin
            window_valid <= 1'b0;                    // da xu ly, cho cua so moi
        end
    end
endmodule