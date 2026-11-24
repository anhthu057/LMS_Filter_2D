`timescale 1ns / 1ps

module lms_2d_top #(
    parameter IMG_WIDTH  = 256,
    parameter DATA_WIDTH = 8,
    parameter WEIGHT_W   = 8,
    parameter MU_SHIFT   = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    input  wire                  pixel_valid_in,
    input  wire [DATA_WIDTH-1:0] pixel_in,
    
    input  wire [DATA_WIDTH-1:0] d_in,
    
    output wire [DATA_WIDTH-1:0] pixel_out,
    output wire                  pixel_valid_out
);

    wire [DATA_WIDTH-1:0] p0, p1, p2;
    wire [DATA_WIDTH-1:0] p3, p4, p5;
    wire [DATA_WIDTH-1:0] p6, p7, p8;
    
    wire window_valid_int;
    
    assign pixel_valid_out = window_valid_int;

    kernel #(
        .IMG_WIDTH  (IMG_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_kernel (
        .clk          (clk),
        .rst_n        (rst_n),
        .pixel_valid  (pixel_valid_in),
        .pixel_in     (pixel_in),
        
        .w00(p0), .w01(p1), .w02(p2),
        .w10(p3), .w11(p4), .w12(p5),
        .w20(p6), .w21(p7), .w22(p8),
        
        .window_valid (window_valid_int)
    );

    lms_2d_core #(
        .DATA_WIDTH (DATA_WIDTH),
        .WEIGHT_W   (WEIGHT_W),
        .MU_SHIFT   (MU_SHIFT)
    ) u_lms_core (
        .clk          (clk),
        .rst_n        (rst_n),
        .window_valid (window_valid_int), 
        
        .p0(p0), .p1(p1), .p2(p2),
        .p3(p3), .p4(p4), .p5(p5),
        .p6(p6), .p7(p7), .p8(p8),
        
        .d_in         (d_in),
        .pixel_out    (pixel_out)
    );

endmodule