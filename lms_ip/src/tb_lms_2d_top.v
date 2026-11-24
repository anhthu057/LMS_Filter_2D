`timescale 1ns / 1ps

module tb_lms_2d_top;

    // 1. C?u hình tham s? ?nh (Ví d?: 256x256)
    parameter IMG_WIDTH  = 256;
    parameter DATA_WIDTH = 8;
    parameter WEIGHT_W   = 8;
    parameter MU_SHIFT   = 18; // H? s? h?c ?ã t?i ?u
    
    parameter TOTAL_PIXELS = IMG_WIDTH * IMG_WIDTH;

    // 2. Khai báo tín hi?u
    reg clk;
    reg rst_n;
    
    reg pixel_valid_in;
    reg [DATA_WIDTH-1:0] pixel_in;
    reg [DATA_WIDTH-1:0] d_in;
    
    wire [DATA_WIDTH-1:0] pixel_out;
    wire pixel_valid_out;

    // 3. K?t n?i Top Module (UUT)
    lms_2d_top #(
        .IMG_WIDTH(IMG_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .WEIGHT_W(WEIGHT_W),
        .MU_SHIFT(MU_SHIFT)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid_in(pixel_valid_in),
        .pixel_in(pixel_in),
        .d_in(d_in),
        .pixel_out(pixel_out),
        .pixel_valid_out(pixel_valid_out)
    );

    // 4. T?o Xung Nh?p 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // 5. Khai báo b? nh? và File I/O
    reg [DATA_WIDTH-1:0] noisy_mem [0:TOTAL_PIXELS-1];
    reg [DATA_WIDTH-1:0] clean_mem [0:TOTAL_PIXELS-1];
    
    integer file_out;
    integer i;
    integer out_count;

    // 6. K?ch b?n ch?y Mô ph?ng
    initial begin
        // A. ??c d? li?u t? file trên máy tính (Nh? copy 2 file này vào th? m?c mô ph?ng)
        $readmemh("noisy05.hex", noisy_mem);
        $readmemh("05.hex", clean_mem);
        
        // B. M? file ?? ghi k?t qu? ra
        file_out = $fopen("filtered05.hex", "w");
        if (file_out == 0) begin
            $display("LOI: Khong the tao file output!");
            $finish;
        end

        // C. Kh?i ??ng h? th?ng
        rst_n = 0;
        pixel_valid_in = 0;
        pixel_in = 0;
        d_in = 0;
        out_count = 0;

        #20;
        rst_n = 1;
        #10;
        
        $display("Bat dau qua trinh loc anh...");

        // D. B?m ?nh tu?n t? vào h? th?ng
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            @(posedge clk);
            pixel_valid_in <= 1'b1;
            
            // Input là ?nh nhi?u
            pixel_in <= noisy_mem[i];
            
            // d_in là ?nh s?ch NH?NG PH?I ???C LÀM TR? (Delay) 
            // V? trí trung tâm c?a khung 3x3 cách v? trí n?p hi?n t?i ?úng (1 hàng + 1 c?t)
            if (i >= (IMG_WIDTH + 1)) begin
                d_in <= clean_mem[i - IMG_WIDTH - 1];
            end else begin
                d_in <= 8'd0;
            end
        end

        // E. D?n d?p ???ng ?ng sau khi b?m h?t ?nh
        @(posedge clk);
        pixel_valid_in <= 1'b0;
        
        // Ch? thêm m?t chút ?? các pixel cu?i cùng r?t h?t ra kh?i Pipeline
        #100;
        
        // F. ?óng file và k?t thúc
        $fclose(file_out);
        $display("Hoan tat! Da xuat %0d pixel ra file 'filtered05.hex'.", out_count);
        $finish;
    end

    // 7. Kh?i Giám sát & Ghi File T? ??ng
    // M?i khi Top module báo valid_out = 1, ta tóm l?y pixel ?ó và ghi vào file
    always @(posedge clk) begin
        if (rst_n && pixel_valid_out) begin
            // %02x dùng ?? ghi ? ??nh d?ng Hex 2 ch? s? (VD: 1F, A3)
            $fdisplay(file_out, "%02x", pixel_out);
            out_count = out_count + 1;
        end
    end

endmodule