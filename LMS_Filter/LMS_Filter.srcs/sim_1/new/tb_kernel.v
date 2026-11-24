`timescale 1ns / 1ps
module tb_kernel;

    // 1. C?u hình tham s? cho Testbench
    parameter IMG_WIDTH  = 5;
    parameter DATA_WIDTH = 8;
    parameter TOTAL_PIXELS = IMG_WIDTH * IMG_WIDTH; // 25 pixels

    // 2. Khai báo các tín hi?u k?t n?i
    reg clk;
    reg rst_n;
    reg pixel_valid;
    reg [DATA_WIDTH-1:0] pixel_in;

    wire [DATA_WIDTH-1:0] w00, w01, w02;
    wire [DATA_WIDTH-1:0] w10, w11, w12;
    wire [DATA_WIDTH-1:0] w20, w21, w22;
    wire window_valid;

    // 3. G?i module (Instantiate UUT - Unit Under Test)
    kernel #(
        .IMG_WIDTH(IMG_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(pixel_valid),
        .pixel_in(pixel_in),
        .w00(w00), .w01(w01), .w02(w02),
        .w10(w10), .w11(w11), .w12(w12),
        .w20(w20), .w21(w21), .w22(w22),
        .window_valid(window_valid)
    );

    // 4. Khai báo m?ng nh? gi? l?p File ?nh
    reg [DATA_WIDTH-1:0] image_mem [0:TOTAL_PIXELS-1];
    integer i;

    // 5. T?o dao ??ng Xung nh?p (Clock) chu k? 10ns (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // 6. K?ch b?n b?m d? li?u (Stimulus)
    initial begin
        // ??c d? li?u t? file hex n?p vào m?ng image_mem
        $readmemh("image.txt", image_mem);

        // Kh?i t?o ngõ vào
        rst_n = 0;
        pixel_valid = 0;
        pixel_in = 0;

        // Ch? 20ns r?i nh? Reset
        #20;
        rst_n = 1;
        #10;

        // B?t ??u b?m t?ng pixel vào module ? m?i nh?p Clock
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            @(posedge clk);
            pixel_valid <= 1'b1;
            pixel_in    <= image_mem[i]; // L?y l?n l??t t? 1 ??n 25
        end

        // B?m xong 25 pixel, ng?t tín hi?u valid
        @(posedge clk);
        pixel_valid <= 1'b0;

        // ??i thêm vài nh?p clock r?i k?t thúc mô ph?ng
        #50;
        $finish;
    end

    // 7. M?ch t? ??ng in k?t qu? (Monitor) - R?t quan tr?ng!
    // M?i khi c? window_valid b?t lên 1, nó s? in khung 3x3 ra màn hình
    always @(posedge clk) begin
        if (window_valid) begin
            $display("--- Valid Window at Time %0t ---", $time);
            $display(" [%02d]  [%02d]  [%02d]", w00, w01, w02);
            $display(" [%02d]  [%02d]  [%02d]", w10, w11, w12);
            $display(" [%02d]  [%02d]  [%02d]\n", w20, w21, w22);
        end
    end

endmodule