//`timescale 1ns / 1ps
//// ============================================================================
//// tb_kernel.v - Kiem tra module kernel (cua so 3x3 + can chinh d_center)
////   Anh nho W x H, moi pixel mang "dia chi" cua no:
////     noisy = {frame[1:0], r[2:0], c[2:0]},  clean = ~noisy
////   => sau moi lan dich, TB biet chinh xac 9 pixel cua cua so phai la gi.
//// Cac kich ban:
////   T1 reset             T2 frame lien tuc (shift + consume moi chu ky)
////   T3 frame ngat quang ngau nhien (shift/consume ngau nhien)
////   T4 frame ngan ket thuc bang pixel_last -> bo dem phai ve (0,0)
////   T5 reset giua frame  T6 frame binh thuong sau tat ca cac su kien tren
//// ============================================================================
//module tb_kernel;
//    localparam W = 8, H = 6;                  // W,H <= 8 de ma hoa vao 3 bit
//    reg clk = 0; always #5 clk = ~clk;

//    reg        rst_n = 0, shift_en = 0, consume = 0, pixel_last = 0;
//    reg  [7:0] pixel_in = 0, d_in = 0;
//    wire [7:0] w00, w01, w02, w10, w11, w12, w20, w21, w22, d_center;
//    wire       window_valid, window_sof, window_eof, frame_start;

//    kernel #(.IMG_WIDTH(W), .IMG_HEIGHT(H), .DATA_WIDTH(8)) dut (
//        .clk(clk), .rst_n(rst_n), .shift_en(shift_en), .consume(consume),
//        .pixel_in(pixel_in), .d_in(d_in), .pixel_last(pixel_last),
//        .w00(w00), .w01(w01), .w02(w02), .w10(w10), .w11(w11), .w12(w12),
//        .w20(w20), .w21(w21), .w22(w22), .d_center(d_center),
//        .window_valid(window_valid), .window_sof(window_sof),
//        .window_eof(window_eof), .frame_start(frame_start));

//    // ---------------- Ham tao du lieu theo vi tri ----------------
//    function [7:0] NZ(input integer f, input integer r, input integer c);
//        NZ = {f[1:0], r[2:0], c[2:0]};
//    endfunction
//    function [7:0] CL(input integer f, input integer r, input integer c);
//        CL = ~NZ(f, r, c);
//    endfunction

//    // ---------------- Mo hinh tham chieu ----------------
//    integer f = 0, r = 0, c = 0;          // vi tri pixel SAP vao
//    integer wf, wr, wc;                    // vi tri pixel moi nhat cua cua so hien tai
//    reg     exp_wv = 0, exp_sof = 0, exp_eof = 0;
//    integer errors = 0, checks = 0, n_sof = 0, n_eof = 0;

//    task fail(input [8*48-1:0] msg);
//        begin
//            errors = errors + 1;
//            if (errors <= 20)
//                $display("[%0t] LOI: %0s  (frame %0d, cua so moi nhat r=%0d c=%0d)", $time, msg, wf, wr, wc);
//        end
//    endtask

//    task check_window;
//        begin
//            checks = checks + 1;
//            if (window_valid !== exp_wv) fail("window_valid sai");
//            if (exp_wv) begin
//                if (w00 !== NZ(wf, wr-2, wc-2) || w01 !== NZ(wf, wr-2, wc-1) || w02 !== NZ(wf, wr-2, wc) ||
//                    w10 !== NZ(wf, wr-1, wc-2) || w11 !== NZ(wf, wr-1, wc-1) || w12 !== NZ(wf, wr-1, wc) ||
//                    w20 !== NZ(wf, wr,   wc-2) || w21 !== NZ(wf, wr,   wc-1) || w22 !== NZ(wf, wr,   wc))
//                    fail("noi dung cua so 3x3 sai");
//                if (d_center !== CL(wf, wr-1, wc-1)) fail("d_center khong o tam cua so");
//                if (window_sof !== exp_sof) fail("window_sof sai");
//                if (window_eof !== exp_eof) fail("window_eof sai");
//            end
//        end
//    endtask

//    // Mot chu ky clock: do_shift / do_consume / is_last
//    task step(input do_shift, input do_consume, input is_last);
//        begin
//            @(negedge clk);
//            shift_en   = do_shift;
//            consume    = do_consume;
//            pixel_last = is_last;
//            pixel_in   = do_shift ? NZ(f, r, c) : 8'hxx;   // x khi khong dich: phat hien dung nham
//            d_in       = do_shift ? CL(f, r, c) : 8'hxx;
//            #1;
//            if (frame_start !== (r == 0 && c == 0)) fail("frame_start sai");
//            @(posedge clk); #1;
//            if (do_shift) begin
//                wf = f; wr = r; wc = c;
//                exp_wv  = (r >= 2) && (c >= 2);
//                exp_sof = (r == 2) && (c == 2);
//                exp_eof = (r == H-1) && (c == W-1);
//                if (exp_wv && exp_sof) n_sof = n_sof + 1;
//                if (exp_wv && exp_eof) n_eof = n_eof + 1;
//                if (is_last || (r == H-1 && c == W-1)) begin r = 0; c = 0; f = f + 1; end
//                else if (c == W-1) begin c = 0; r = r + 1; end
//                else c = c + 1;
//            end else if (do_consume) begin
//                exp_wv = 0;
//            end
//            check_window;
//        end
//    endtask

//    integer i;
//    initial begin
//        $dumpfile("tb_kernel.vcd"); $dumpvars(0, tb_kernel);

//        // T1: reset
//        #12;
//        if (window_valid !== 0 || frame_start !== 1) fail("trang thai reset sai");
//        rst_n = 1;

//        // T2: frame 0 lien tuc
//        $display("T2: frame lien tuc");
//        for (i = 0; i < W*H; i = i + 1) step(1, 1, 0);

//        // T3: frame 1 ngat quang ngau nhien
//        $display("T3: frame ngat quang, consume ngau nhien");
//        i = 0;
//        while (i < W*H) begin
//            if ($random & 1) begin step(1, $random & 1, 0); i = i + 1; end
//            else step(0, $random & 1, 0);
//        end

//        // T4: frame ngan, ket thuc bang pixel_last tai (2, 4)
//        $display("T4: frame ngan ket thuc bang pixel_last");
//        for (i = 0; i < 2*W + 5; i = i + 1) step(1, 1, (i == 2*W + 4));
//        if (r !== 0 || c !== 0) fail("mo hinh TB khong ve (0,0)");
//        #1 if (frame_start !== 1) fail("bo dem khong ve (0,0) sau pixel_last");

//        // T5: reset giua frame
//        $display("T5: reset giua frame");
//        for (i = 0; i < 3*W + 2; i = i + 1) step(1, 1, 0);
//        @(negedge clk) rst_n = 0; shift_en = 0; consume = 0;
//        @(negedge clk) rst_n = 1;
//        r = 0; c = 0; f = f + 1; exp_wv = 0;
//        #1 if (window_valid !== 0 || frame_start !== 1) fail("reset giua frame khong ve trang thai dau");

//        // T6: hai frame binh thuong, ngat quang
//        $display("T6: hai frame sau cac su kien");
//        i = 0;
//        while (i < 2*W*H) begin
//            if (($random & 3) != 0) begin step(1, 1, 0); i = i + 1; end
//            else step(0, 0, 0);       // khong consume: window_valid phai duoc giu
//        end

//        // Tong ket: 4 frame day du (frame 0,1 va 2 frame T6) co sof+eof; frame T4 va T5 chi co sof
//        if (n_sof !== 6) begin $display("LOI: dem duoc %0d window_sof, mong doi 6", n_sof); errors = errors + 1; end
//        if (n_eof !== 4) begin $display("LOI: dem duoc %0d window_eof, mong doi 4", n_eof); errors = errors + 1; end

//        if (errors == 0) $display("==> tb_kernel PASS (%0d lan kiem tra)", checks);
//        else             $display("==> tb_kernel FAIL: %0d loi", errors);
//        $finish;
//    end
//endmodule


`timescale 1ns / 1ps

module tb_kernel;
    localparam W = 256, H = 256;
    reg clk = 0; 
    always #5 clk = ~clk; // Chu kỳ clock 10ns (100MHz)

    reg        rst_n = 0, shift_en = 0, consume = 0, pixel_last = 0;
    reg  [7:0] pixel_in = 0, d_in = 0;
    wire [7:0] w00, w01, w02, w10, w11, w12, w20, w21, w22, d_center;
    wire       window_valid, window_sof, window_eof, frame_start;

    // Bộ nhớ chứa dữ liệu ảnh thật 256x256 (65,536 bytes)
    reg [7:0] mem_noisy [0:W*H-1];
    reg [7:0] mem_clean [0:W*H-1];

    kernel #(
        .IMG_WIDTH(W), 
        .IMG_HEIGHT(H), 
        .DATA_WIDTH(8)
    ) dut (
        .clk(clk), .rst_n(rst_n), .shift_en(shift_en), .consume(consume),
        .pixel_in(pixel_in), .d_in(d_in), .pixel_last(pixel_last),
        .w00(w00), .w01(w01), .w02(w02), 
        .w10(w10), .w11(w11), .w12(w12),
        .w20(w20), .w21(w21), .w22(w22), 
        .d_center(d_center),
        .window_valid(window_valid), .window_sof(window_sof),
        .window_eof(window_eof), .frame_start(frame_start)
    );

    // ---------------- Mô hình tham chiếu ----------------
    integer f = 0, r = 0, c = 0;   // Tọa độ pixel SẮP đi vào
    integer wf, wr, wc;            // Tọa độ pixel góc dưới phải của cửa sổ hiện tại
    reg     exp_wv = 0, exp_sof = 0, exp_eof = 0;
    integer errors = 0, checks = 0, n_sof = 0, n_eof = 0;

    task fail(input [8*56-1:0] msg);
        begin
            errors = errors + 1;
            if (errors <= 20)
                $display("[%0t] LOI: %0s (frame %0d, goc duoi phai r=%0d, c=%0d)", $time, msg, wf, wr, wc);
        end
    endtask

    task check_window;
        begin
            checks = checks + 1;
            if (window_valid !== exp_wv) fail("window_valid sai");
            if (exp_wv) begin
                // Đối chiếu trực tiếp 9 pixel đầu ra của kernel với mảng mem_noisy
                if (w00 !== mem_noisy[(wr-2)*W + (wc-2)] || 
                    w01 !== mem_noisy[(wr-2)*W + (wc-1)] || 
                    w02 !== mem_noisy[(wr-2)*W + wc]     ||
                    w10 !== mem_noisy[(wr-1)*W + (wc-2)] || 
                    w11 !== mem_noisy[(wr-1)*W + (wc-1)] || 
                    w12 !== mem_noisy[(wr-1)*W + wc]     ||
                    w20 !== mem_noisy[wr*W     + (wc-2)] || 
                    w21 !== mem_noisy[wr*W     + (wc-1)] || 
                    w22 !== mem_noisy[wr*W     + wc])
                    fail("noi dung cua so 3x3 khong khop anh nhiễu");

                // Đối chiếu pixel tâm d_center với mảng mem_clean
                if (d_center !== mem_clean[(wr-1)*W + (wc-1)])
                    fail("d_center khong khop anh sach tai tam (wr-1, wc-1)");

                if (window_sof !== exp_sof) fail("window_sof sai");
                if (window_eof !== exp_eof) fail("window_eof sai");
            end
        end
    endtask

    // Bơm dữ liệu từng chu kỳ clock
    task step(input do_shift, input do_consume, input is_last);
        begin
            @(negedge clk);
            shift_en   = do_shift;
            consume    = do_consume;
            pixel_last = is_last;
            pixel_in   = do_shift ? mem_noisy[r*W + c] : 8'hxx;
            d_in       = do_shift ? mem_clean[r*W + c] : 8'hxx;
            #1;
            if (frame_start !== (r == 0 && c == 0)) fail("frame_start sai");
            
            @(posedge clk); #1;
            if (do_shift) begin
                wf = f; wr = r; wc = c;
                exp_wv  = (r >= 2) && (c >= 2);
                exp_sof = (r == 2) && (c == 2);
                exp_eof = (r == H-1) && (c == W-1);
                if (exp_wv && exp_sof) n_sof = n_sof + 1;
                if (exp_wv && exp_eof) n_eof = n_eof + 1;

                if (is_last || (r == H-1 && c == W-1)) begin 
                    r = 0; c = 0; f = f + 1; 
                end else if (c == W-1) begin 
                    c = 0; r = r + 1; 
                end else begin
                    c = c + 1;
                end
            end else if (do_consume) begin
                exp_wv = 0;
            end
            check_window;
        end
    endtask

    integer i;
    initial begin
        // Nạp dữ liệu từ 2 file .hex vào bộ nhớ mô phỏng
        $readmemh("01_gaussian_noise_image_0.01.hex", mem_noisy);
        $readmemh("01.hex", mem_clean);

        // Kiểm tra xem file có nạp thành công không (nếu lỗi file, phần tử 0 sẽ là X)
        if (mem_noisy[0] === 8'hxx || mem_clean[0] === 8'hxx) begin
            $display("LOI NGHIEM TRONG: Khong tim thay file .hex! Hay them file vao Simulation Sources.");
            $finish;
        end

        // T1: Kiểm tra Reset
        #12;
        if (window_valid !== 0 || frame_start !== 1) fail("trang thai reset sai");
        rst_n = 1;

        // T2: Bơm 1 khung hình 256x256 liên tục
        $display("T2: Frame 256x256 lien tuc...");
        for (i = 0; i < W*H; i = i + 1) step(1, 1, 0);

        // T3: Bơm 1 khung hình 256x256 ngắt quãng ngẫu nhiên (mô phỏng nghẽn bus AXI)
        $display("T3: Frame 256x256 ngat quang ngau nhien...");
        i = 0;
        while (i < W*H) begin
            if ($random & 1) begin step(1, $random & 1, 0); i = i + 1; end
            else step(0, $random & 1, 0);
        end

        // T4: Frame ngắn kết thúc sớm bằng pixel_last tại hàng 2, cột 4
        $display("T4: Frame ngan ket thuc bang pixel_last...");
        for (i = 0; i < 2*W + 5; i = i + 1) step(1, 1, (i == 2*W + 4));
        if (r !== 0 || c !== 0) fail("mo hinh TB khong ve (0,0)");
        #1 if (frame_start !== 1) fail("bo dem khong ve (0,0) sau pixel_last");

        // T5: Reset giữa chừng khi đang chạy ở hàng 3
        $display("T5: Reset giua frame...");
        for (i = 0; i < 3*W + 2; i = i + 1) step(1, 1, 0);
        @(negedge clk) rst_n = 0; shift_en = 0; consume = 0;
        @(negedge clk) rst_n = 1;
        r = 0; c = 0; f = f + 1; exp_wv = 0;
        #1 if (window_valid !== 0 || frame_start !== 1) fail("reset giua frame khong ve trang thai dau");

        // T6: Chạy tiếp 2 khung hình 256x256 đầy đủ sau các biến cố
        $display("T6: Hai frame 256x256 sau cac su kien...");
        i = 0;
        while (i < 2*W*H) begin
            if (($random & 3) != 0) begin step(1, 1, 0); i = i + 1; end
            else step(0, 0, 0);
        end

        // Tổng kết kiểm tra số lượng cờ SOF và EOF
        if (n_sof !== 6) begin $display("LOI: dem duoc %0d window_sof, mong doi 6", n_sof); errors = errors + 1; end
        if (n_eof !== 4) begin $display("LOI: dem duoc %0d window_eof, mong doi 4", n_eof); errors = errors + 1; end

        if (errors == 0) $display("==> tb_kernel PASS (%0d lan kiem tra thanh cong voi anh 256x256)", checks);
        else             $display("==> tb_kernel FAIL: Phat hien %0d loi", errors);
        $finish;
    end
endmodule