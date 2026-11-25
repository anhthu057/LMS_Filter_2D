`timescale 1ns / 1ps
// ============================================================================
// lms_axi_wrapper.v - Giao tiep AXI4-Stream cho AXI DMA
//   S_AXIS (16 bit): TDATA[7:0] = pixel nhieu, TDATA[15:8] = pixel sach
//                    -> chi can 1 kenh MM2S cua 1 AXI DMA
//   M_AXIS (8 bit) : anh da loc 254x254, TLAST o pixel cuoi
// ============================================================================
module lms_axi_wrapper #(
    parameter IMG_WIDTH  = 256,
    parameter IMG_HEIGHT = 256,
    parameter MU_LOG2    = 5
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 ACLK CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXIS:M_AXIS, ASSOCIATED_RESET ARESETN" *)
    input  wire        ACLK,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 ARESETN RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        ARESETN,

    input  wire [15:0] S_AXIS_TDATA,
    input  wire        S_AXIS_TVALID,
    output wire        S_AXIS_TREADY,
    input  wire        S_AXIS_TLAST,

    output wire [7:0]  M_AXIS_TDATA,
    output wire        M_AXIS_TVALID,
    input  wire        M_AXIS_TREADY,
    output wire        M_AXIS_TLAST,
    output wire        M_AXIS_TUSER
);
    lms_2d_top #(
        .IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT), .DATA_WIDTH(8),
        .WEIGHT_W(24), .FRAC(18), .MU_LOG2(MU_LOG2), .RESET_W_PER_FRAME(1)
    ) u_lms_top (
        .clk(ACLK), .rst_n(ARESETN),
        .in_valid(S_AXIS_TVALID), .in_ready(S_AXIS_TREADY),
        .pixel_in(S_AXIS_TDATA[7:0]), .d_in(S_AXIS_TDATA[15:8]), .in_last(S_AXIS_TLAST),
        .out_data(M_AXIS_TDATA), .out_valid(M_AXIS_TVALID), .out_ready(M_AXIS_TREADY),
        .out_last(M_AXIS_TLAST), .out_user(M_AXIS_TUSER)
    );
endmodule