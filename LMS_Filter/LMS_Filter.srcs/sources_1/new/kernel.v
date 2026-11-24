`timescale 1ns / 1ps

module kernel #(
    parameter IMG_WIDTH  = 256, //image size
    parameter DATA_WIDTH = 8 // 8-bit for 1 pixel  
)(
    input  wire                  clk,
    input  wire                  rst_n,      // Active-low reset
    input  wire                  pixel_valid,   // signal: have pixel in
    input  wire [DATA_WIDTH-1:0] pixel_in,   // pixel in data
    
    output reg  [DATA_WIDTH-1:0] w00, w01, w02, // row 1
    output reg  [DATA_WIDTH-1:0] w10, w11, w12, // row 2
    output reg  [DATA_WIDTH-1:0] w20, w21, w22, // row 3 (newest)
    
    output reg                   window_valid   // signal: have window out
);

    // 2 buffer have IMG_WIDTH element and 1 element have IMG_WIDTH bit
    reg [DATA_WIDTH-1:0] line_buffer_1 [0:IMG_WIDTH-1];
    reg [DATA_WIDTH-1:0] line_buffer_2 [0:IMG_WIDTH-1];
    
    // circuler pointer
    reg [$clog2(IMG_WIDTH)-1:0] ptr; 
    
    // 
    wire [DATA_WIDTH-1:0] pop_lb1;
    wire [DATA_WIDTH-1:0] pop_lb2;
    
    // 
    assign pop_lb1 = line_buffer_1[ptr];
    assign pop_lb2 = line_buffer_2[ptr];
    
    // control signal
    reg [8:0] x_cnt; // column
    reg [8:0] y_cnt; // row
    
    // Main Process
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset system
            ptr   <= 0;
            x_cnt <= 0;
            y_cnt <= 0;
            
            w00 <= 0; w01 <= 0; w02 <= 0;
            w10 <= 0; w11 <= 0; w12 <= 0;
            w20 <= 0; w21 <= 0; w22 <= 0;
            
            window_valid <= 1'b0;
        end 
        else if (pixel_valid) begin
            
            // matrix 3x3 
            // column 1 -> 0
            w00 <= w01; w10 <= w11; w20 <= w21;
            // column 2 -> 1
            w01 <= w02; w11 <= w12; w21 <= w22;
            
            // column 2 = new data
            w02 <= pop_lb2;   // w02 = data out of buffer 2
            w12 <= pop_lb1;   // w12 = data out of buffer 1
            w22 <= pixel_in;  // w22 = new pixel data
            
            // update data for Line Buffers 
            line_buffer_1[ptr] <= pixel_in; // new pixel data push to LB1
            line_buffer_2[ptr] <= pop_lb1;  // push pixel from LB1 to LB2
            
            // update signal for pointer and counter
            if (ptr == IMG_WIDTH - 1) begin
                ptr   <= 0;
                x_cnt <= 0;
                y_cnt <= y_cnt + 1;
            end else begin
                ptr   <= ptr + 1;
                x_cnt <= x_cnt + 1;
            end
            
            // check window_valid signal
            // window_valid = 1 when x_cnt >= 2 and y_cnt >= 2
            if (x_cnt >= 2 && y_cnt >= 2) begin
                window_valid <= 1'b1;
            end else begin
                window_valid <= 1'b0;
            end
            
        end else begin
            // if pixel_valid = 0, do nothing
            window_valid <= 1'b0;
        end
    end

endmodule
