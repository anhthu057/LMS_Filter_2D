`timescale 1ns / 1ps

module lms_axi_wrapper #(
    parameter IMG_WIDTH = 256
)(
    input wire ACLK,
    input wire ARESETN, 

    // 1. KÊNH NGÕ VÀO (?NH NHI?U)
    input  wire [7:0] S_AXIS_NOISY_TDATA,
    input  wire       S_AXIS_NOISY_TVALID,
    output wire       S_AXIS_NOISY_TREADY, 
    input  wire       S_AXIS_NOISY_TLAST,
    input  wire       S_AXIS_NOISY_TUSER,

    // 2. KÊNH NGÕ VÀO (?NH S?CH - ?? TÍNH ERROR)
    input  wire [7:0] S_AXIS_CLEAN_TDATA,
    input  wire       S_AXIS_CLEAN_TVALID,
    output wire       S_AXIS_CLEAN_TREADY,

    // 3. KÊNH NGÕ RA (?NH ?Ã L?C)
    output wire [7:0] M_AXIS_TDATA,
    output wire       M_AXIS_TVALID,
    input  wire       M_AXIS_TREADY,
    output wire       M_AXIS_TLAST,
    output wire       M_AXIS_TUSER
);

    // ?i?u ki?n Fire: C? 2 ngõ vào có d? li?u và ngõ ra s?n sàng nh?n
    wire fire_in = S_AXIS_NOISY_TVALID && S_AXIS_CLEAN_TVALID && M_AXIS_TREADY;
    
    assign S_AXIS_NOISY_TREADY = S_AXIS_CLEAN_TVALID && M_AXIS_TREADY;
    assign S_AXIS_CLEAN_TREADY = S_AXIS_NOISY_TVALID && M_AXIS_TREADY;

    // G?i module TOP c?a b?n
    wire [7:0] pixel_out_int;
    wire       valid_out_int;

    lms_2d_top #(
        .IMG_WIDTH(IMG_WIDTH),
        .DATA_WIDTH(8),
        .WEIGHT_W(8),
        .MU_SHIFT(19) 
    ) u_lms_top (
        .clk             (ACLK),
        .rst_n           (ARESETN),
        .pixel_valid_in  (fire_in),            
        .pixel_in        (S_AXIS_NOISY_TDATA), 
        .d_in            (S_AXIS_CLEAN_TDATA), 
        .pixel_out       (pixel_out_int),
        .pixel_valid_out (valid_out_int)
    );

    assign M_AXIS_TDATA  = pixel_out_int;
    assign M_AXIS_TVALID = valid_out_int;

    // B? ??NG B? TR? (DELAY LINE) CHO TLAST & TUSER
    // Kernel c?n quét qua 2 hàng + 2 c?t (IMG_WIDTH*2 + 2) ?? xu?t pixel ??u tiên
    // M?t thêm 1 clock cho logic tính toán lõi -> t?ng tr? là IMG_WIDTH*2 + 3
    localparam DELAY_CYCLES = (2 * IMG_WIDTH) + 3;

    reg [DELAY_CYCLES-1:0] tlast_shift;
    reg [DELAY_CYCLES-1:0] tuser_shift;

    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            tlast_shift <= 0;
            tuser_shift <= 0;
        end else if (fire_in) begin
            // Ch? d?ch bit khi có pixel h?p l? ?i vào
            tlast_shift <= {tlast_shift[DELAY_CYCLES-2:0], S_AXIS_NOISY_TLAST};
            tuser_shift <= {tuser_shift[DELAY_CYCLES-2:0], S_AXIS_NOISY_TUSER};
        end
    end

    assign M_AXIS_TLAST = tlast_shift[DELAY_CYCLES-1];
    assign M_AXIS_TUSER = tuser_shift[DELAY_CYCLES-1];

endmodule