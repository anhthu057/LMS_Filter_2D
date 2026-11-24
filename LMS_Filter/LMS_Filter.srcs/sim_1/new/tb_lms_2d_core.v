`timescale 1ns / 1ps

module tb_lms_2d_core;

    // 1. C?u hình tham s? (Ch?n MU_SHIFT = 4 ?? AI h?c nhanh h?n trong mô ph?ng)
    parameter DATA_WIDTH = 8;
    parameter WEIGHT_W   = 8;
    parameter MU_SHIFT   = 4; 

    // 2. Khai báo tín hi?u
    reg clk;
    reg rst_n;
    reg window_valid;

    reg [DATA_WIDTH-1:0] p0, p1, p2;
    reg [DATA_WIDTH-1:0] p3, p4, p5;
    reg [DATA_WIDTH-1:0] p6, p7, p8;
    
    reg [DATA_WIDTH-1:0] d_in;
    wire [DATA_WIDTH-1:0] pixel_out;

    // 3. G?i module (UUT)
    lms_2d_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .WEIGHT_W(WEIGHT_W),
        .MU_SHIFT(MU_SHIFT)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .window_valid(window_valid),
        .p0(p0), .p1(p1), .p2(p2),
        .p3(p3), .p4(p4), .p5(p5),
        .p6(p6), .p7(p7), .p8(p8),
        .d_in(d_in),
        .pixel_out(pixel_out)
    );

    // 4. T?o Xung nh?p (Clock) chu k? 10ns
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // 5. K?ch b?n mô ph?ng
    integer i;
    initial begin
        // Kh?i t?o
        rst_n = 0;
        window_valid = 0;
        p0 = 0; p1 = 0; p2 = 0;
        p3 = 0; p4 = 0; p5 = 0;
        p6 = 0; p7 = 0; p8 = 0;
        d_in = 0;

        // B? Reset
        #20;
        rst_n = 1;
        #10;

        $display("=== GIAI DOAN 1: DAY AI HOC GIA TRI p4 ===");
        window_valid = 1;
        for (i = 0; i < 300; i = i + 1) begin
            @(posedge clk);
            // B?m nhi?u ng?u nhiên vào 9 pixel
            p0 <= $random % 256; p1 <= $random % 256; p2 <= $random % 256;
            p3 <= $random % 256; p4 <= $random % 256; p5 <= $random % 256;
            p6 <= $random % 256; p7 <= $random % 256; p8 <= $random % 256;
            
            // D?y AI: "??u ra mong mu?n chính là p4"
            d_in <= p4; 
        end

        $display("\n=== GIAI DOAN 2: TEST DONG BANG (window_valid = 0) ===");
        window_valid = 0; // T?t c? valid
        for (i = 0; i < 20; i = i + 1) begin
            @(posedge clk);
            p0 <= $random % 256; p1 <= $random % 256; p2 <= $random % 256;
            p3 <= $random % 256; p4 <= $random % 256; p5 <= $random % 256;
            p6 <= $random % 256; p7 <= $random % 256; p8 <= $random % 256;
            d_in <= p4; // V?n b?t nó target p4 nh?ng c? valid = 0
        end

        $display("\n=== GIAI DOAN 3: DAY AI HOC MUC TIEU MOI (p0) ===");
        window_valid = 1; // B?t l?i c? valid
        for (i = 0; i < 300; i = i + 1) begin
            @(posedge clk);
            p0 <= $random % 256; p1 <= $random % 256; p2 <= $random % 256;
            p3 <= $random % 256; p4 <= $random % 256; p5 <= $random % 256;
            p6 <= $random % 256; p7 <= $random % 256; p8 <= $random % 256;
            
            // ??i bài toán: "Bây gi? tao mu?n ??u ra gi?ng p0 c?!"
            d_in <= p0; 
        end

        #50;
        $display("\n=== HOAN TAT MO PHONG ===");
        $finish;
    end

    // 6. Monitor - Theo dõi tr?ng s? h?i t?
    // Ch? in k?t qu? ra màn hình m?i 50 chu k? clock ?? không b? ng?p ch?
    integer cycle_count = 0;
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count = cycle_count + 1;
            
            if (cycle_count % 50 == 0) begin
                $display("Time: %0t | d_in: %3d | out: %3d | Error: %3d || w0: %4d | w4: %4d | w8: %4d", 
                         $time, d_in, pixel_out, $signed(uut.error), 
                         $signed(uut.weight[0]), 
                         $signed(uut.weight[4]), 
                         $signed(uut.weight[8]));
            end
            
            // In chi ti?t lúc test ?óng b?ng (Giai ?o?n 2)
            if (cycle_count >= 301 && cycle_count <= 305) begin
                $display("FREEZE TEST: Time %0t | Valid=0 | w4 = %4d (Khong duoc thay doi!)", 
                         $time, $signed(uut.weight[4]));
            end
        end
    end

endmodule