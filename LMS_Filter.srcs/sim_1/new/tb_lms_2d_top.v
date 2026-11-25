//`timescale 1ns / 1ps
//// ============================================================================
//// tb_lms_2d_top.v - Kiem tra lms_2d_top (kernel + core + handshake valid/ready)
////   * Anh nho W x H, NF frame, moi frame la anh ngau nhien khac nhau
////   * TB tu tinh ket qua mong doi bang mo hinh LMS so nguyen (giong lms_golden.py)
////   * Frame 0: in_valid = out_ready = 1 lien tuc -> phai dat 1 pixel/clock
////   * Cac frame sau: in_valid va out_ready ngau nhien (kiem tra stall, backpressure)
////   * Kiem tra quy tac handshake: khi out_valid=1 ma out_ready=0 thi
////     out_valid/out_data/out_last/out_user phai giu nguyen o chu ky sau
////   * Kiem tra out_user o pixel dau, out_last o pixel cuoi moi frame
//// Chay voi ca hai che do reset trong so:
////   iverilog -P tb_lms_2d_top.RESET_W=1 ...   (mac dinh, moi frame doc lap)
////   iverilog -P tb_lms_2d_top.RESET_W=0 ...   (trong so mang sang frame sau)
//// ============================================================================
//module tb_lms_2d_top;
//    parameter RESET_W = 1;
//    parameter MU_LOG2 = 5;
//    localparam W = 16, H = 12, NF = 4;
//    localparam N  = W * H;
//    localparam NO = (W - 2) * (H - 2);
//    localparam FRAC = 18, WW = 24;
//    localparam integer S = MU_LOG2 + 15 - FRAC;
//    localparam signed [63:0] WMAX = (64'sd1 <<< (WW-1)) - 1;
//    localparam signed [63:0] WMIN = -(64'sd1 <<< (WW-1));

//    reg clk = 0; always #5 clk = ~clk;
//    reg rst_n = 0;

//    reg        in_valid = 0, in_last = 0, out_ready = 0;
//    reg  [7:0] pixel_in = 0, d_in = 0;
//    wire       in_ready, out_valid, out_last, out_user;
//    wire [7:0] out_data;

//    lms_2d_top #(.IMG_WIDTH(W), .IMG_HEIGHT(H), .DATA_WIDTH(8), .WEIGHT_W(WW),
//                 .FRAC(FRAC), .MU_LOG2(MU_LOG2), .RESET_W_PER_FRAME(RESET_W)) dut (
//        .clk(clk), .rst_n(rst_n),
//        .in_valid(in_valid), .in_ready(in_ready), .pixel_in(pixel_in), .d_in(d_in), .in_last(in_last),
//        .out_data(out_data), .out_valid(out_valid), .out_ready(out_ready),
//        .out_last(out_last), .out_user(out_user));

//    // ---------------- Du lieu va ket qua mong doi ----------------
//    reg [7:0] img_x [0:NF*N-1];
//    reg [7:0] img_d [0:NF*N-1];
//    reg [7:0] expv  [0:NF*NO-1];

//    reg signed [63:0] w [0:8];
//    reg signed [63:0] xs [0:8];
//    reg signed [63:0] acc, y, e, g, dl, s;
//    integer fr, r, c, i, o;

//    task build_expected;
//        begin
//            for (i = 0; i < 9; i = i + 1) w[i] = (i == 4) ? (64'sd1 <<< FRAC) : 0;
//            o = 0;
//            for (fr = 0; fr < NF; fr = fr + 1) begin
//                if (RESET_W != 0)
//                    for (i = 0; i < 9; i = i + 1) w[i] = (i == 4) ? (64'sd1 <<< FRAC) : 0;
//                for (r = 2; r < H; r = r + 1)
//                    for (c = 2; c < W; c = c + 1) begin
//                        for (i = 0; i < 9; i = i + 1)
//                            xs[i] = img_x[fr*N + (r-2+i/3)*W + (c-2+i%3)];
//                        acc = 0;
//                        for (i = 0; i < 9; i = i + 1) acc = acc + w[i] * xs[i];
//                        y = (acc + (64'sd1 <<< (FRAC-1))) >>> FRAC;
//                        if (y < 0) y = 0; if (y > 255) y = 255;
//                        e = img_d[fr*N + (r-1)*W + (c-1)] - y;
//                        for (i = 0; i < 9; i = i + 1) begin
//                            g  = e * xs[i];
//                            dl = (S > 0) ? ((g + (64'sd1 <<< (S-1))) >>> S) : (g <<< (-S));
//                            s  = w[i] + dl;
//                            w[i] = (s > WMAX) ? WMAX : (s < WMIN) ? WMIN : s;
//                        end
//                        expv[o] = y[7:0]; o = o + 1;
//                    end
//            end
//        end
//    endtask

//    // ---------------- Nguon (master) ----------------
//    integer k = 0;              // so pixel da gui
//    integer mode = 0;           // 0: toc do toi da, 1: ngau nhien
//    integer stall_full = 0;     // so chu ky in_valid=1 nhung in_ready=0 trong frame 0
//    always @(posedge clk) if (rst_n) begin
//        if (in_valid && !in_ready && mode == 0) stall_full = stall_full + 1;
//        if (!in_valid || in_ready) begin
//            if (k < NF*N && (mode == 0 || ($random % 3) != 0)) begin
//                in_valid <= 1;
//                pixel_in <= img_x[k]; d_in <= img_d[k];
//                in_last  <= ((k % N) == N - 1);
//                k = k + 1;
//                if (k == N) mode = 1;      // het frame 0 -> chuyen sang ngau nhien
//            end else begin
//                in_valid <= 0; pixel_in <= 8'hxx; d_in <= 8'hxx; in_last <= 1'bx;
//            end
//        end
//        out_ready <= (mode == 0) ? 1'b1 : (($random % 4) != 0);
//    end

//    // ---------------- Dich (slave) + kiem tra ----------------
//    integer nout = 0, errors = 0, n_last = 0, n_user = 0;
//    reg       prev_stall = 0;
//    reg [7:0] prev_data;
//    reg       prev_last, prev_user;

//    task fail(input [8*48-1:0] msg);
//        begin
//            errors = errors + 1;
//            if (errors <= 20) $display("[%0t] LOI: %0s (pixel ra #%0d)", $time, msg, nout);
//        end
//    endtask

//    always @(posedge clk) if (rst_n) begin
//        // quy tac AXI: da valid ma chua duoc nhan thi phai giu nguyen
//        if (prev_stall) begin
//            if (!out_valid) fail("out_valid bi ha khi chua duoc nhan");
//            else if (out_data !== prev_data || out_last !== prev_last || out_user !== prev_user)
//                fail("du lieu thay doi khi dang bi backpressure");
//        end
//        prev_stall <= out_valid && !out_ready;
//        prev_data  <= out_data; prev_last <= out_last; prev_user <= out_user;

//        if (out_valid && out_ready) begin
//            if (out_data !== expv[nout]) begin
//                fail("out_data sai");
//                if (errors <= 20) $display("        DUT=%0d  MONG DOI=%0d", out_data, expv[nout]);
//            end
//            if (out_user !== ((nout % NO) == 0))      fail("out_user sai vi tri");
//            if (out_last !== ((nout % NO) == NO - 1)) fail("out_last sai vi tri");
//            if (out_user) n_user = n_user + 1;
//            if (out_last) n_last = n_last + 1;
//            nout = nout + 1;
//        end
//    end

//    integer t;
//    initial begin
//        for (i = 0; i < NF*N; i = i + 1) begin
//            img_d[i] = $random;
//            img_x[i] = img_d[i] + ($random % 40);   // anh "nhieu" = anh sach + nhieu
//        end
//        build_expected;
//        $display("tb_lms_2d_top: anh %0dx%0d, %0d frame, RESET_W=%0d, MU_LOG2=%0d", W, H, NF, RESET_W, MU_LOG2);

//        #12;   // sau canh clock dau tien khi rst_n = 0
//        if (out_valid !== 1'b0 || in_ready !== 1'b1) fail("trang thai reset sai");
//        #10 rst_n = 1;

//        t = 0;
//        while (nout < NF*NO && t < 200000) begin @(posedge clk); t = t + 1; end
//        repeat (10) @(posedge clk);

//        if (nout !== NF*NO)   begin $display("LOI: nhan %0d pixel, mong doi %0d", nout, NF*NO); errors = errors + 1; end
//        if (n_last !== NF)    begin $display("LOI: %0d TLAST, mong doi %0d", n_last, NF); errors = errors + 1; end
//        if (n_user !== NF)    begin $display("LOI: %0d TUSER, mong doi %0d", n_user, NF); errors = errors + 1; end
//        if (stall_full !== 0) begin $display("LOI: frame 0 bi stall %0d chu ky (khong dat 1 pixel/clk)", stall_full); errors = errors + 1; end
//        if (out_valid)        begin $display("LOI: con du lieu thua sau khi het frame"); errors = errors + 1; end

//        if (errors == 0) $display("==> tb_lms_2d_top PASS (%0d pixel, %0d frame)", nout, NF);
//        else             $display("==> tb_lms_2d_top FAIL: %0d loi", errors);
//        $finish;
//    end
//endmodule 





`timescale 1ns / 1ps

module tb_lms_2d_top;
    parameter RESET_W = 1;
    parameter MU_LOG2 = 6; // Toc do hoc mu = 2^-6 (co the doi 5, 6, 7)
    localparam W = 256, H = 256, NF = 2;
    localparam N  = W * H;           // 65,536 pixels vao / frame
    localparam NO = (W - 2) * (H - 2); // 64,516 pixels ra / frame
    localparam FRAC = 18, WW = 24;
    localparam integer S = MU_LOG2 + 15 - FRAC;
    localparam signed [63:0] WMAX = (64'sd1 <<< (WW-1)) - 1;
    localparam signed [63:0] WMIN = -(64'sd1 <<< (WW-1));

    reg clk = 0; 
    always #5 clk = ~clk; // 100 MHz
    reg rst_n = 0;

    reg        in_valid = 0, in_last = 0, out_ready = 0;
    reg  [7:0] pixel_in = 0, d_in = 0;
    wire       in_ready, out_valid, out_last, out_user;
    wire [7:0] out_data;

    lms_2d_top #(
        .IMG_WIDTH(W), .IMG_HEIGHT(H), .DATA_WIDTH(8), .WEIGHT_W(WW),
        .FRAC(FRAC), .MU_LOG2(MU_LOG2), .RESET_W_PER_FRAME(RESET_W)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .in_ready(in_ready), .pixel_in(pixel_in), .d_in(d_in), .in_last(in_last),
        .out_data(out_data), .out_valid(out_valid), .out_ready(out_ready),
        .out_last(out_last), .out_user(out_user)
    );

    // ---------------- Du lieu anh that 256x256 va ket qua mong doi ----------------
    reg [7:0] img_x [0:N-1];
    reg [7:0] img_d [0:N-1];
    reg [7:0] expv  [0:NF*NO-1];

    reg signed [63:0] w [0:8];
    reg signed [63:0] xs [0:8];
    reg signed [63:0] acc, y, e, g, dl, s;
    integer fr, r, c, i, o, fd;

    task build_expected;
        begin
            for (i = 0; i < 9; i = i + 1) w[i] = (i == 4) ? (64'sd1 <<< FRAC) : 0;
            o = 0;
            for (fr = 0; fr < NF; fr = fr + 1) begin
                if (RESET_W != 0)
                    for (i = 0; i < 9; i = i + 1) w[i] = (i == 4) ? (64'sd1 <<< FRAC) : 0;
                for (r = 2; r < H; r = r + 1)
                    for (c = 2; c < W; c = c + 1) begin
                        for (i = 0; i < 9; i = i + 1)
                            xs[i] = $signed({56'd0, img_x[(r-2+i/3)*W + (c-2+i%3)]});
                        acc = 0;
                        for (i = 0; i < 9; i = i + 1) acc = acc + w[i] * xs[i];
                        y = (acc + (64'sd1 <<< (FRAC-1))) >>> FRAC;
                        if (y < 0) y = 0; if (y > 255) y = 255;
                        e = $signed({56'd0, img_d[(r-1)*W + (c-1)]}) - y;
                        for (i = 0; i < 9; i = i + 1) begin
                            g  = e * xs[i];
                            dl = (S > 0) ? ((g + (64'sd1 <<< (S-1))) >>> S) : (g <<< (-S));
                            s  = w[i] + dl;
                            w[i] = (s > WMAX) ? WMAX : (s < WMIN) ? WMIN : s;
                        end
                        expv[o] = y[7:0]; o = o + 1;
                    end
            end
        end
    endtask

    // ---------------- Nguon phat AXI-Stream (Master) ----------------
    integer k = 0;          // Tong so pixel da gui
    integer mode = 0;       // 0: toc do toi da (Frame 0), 1: ngau nhien (Frame 1)
    integer stall_full = 0; // Dem so chu ky bi nghen trong Frame 0

    always @(posedge clk) if (rst_n) begin
        if (in_valid && !in_ready && mode == 0) stall_full = stall_full + 1;
        if (!in_valid || in_ready) begin
            if (k < NF*N && (mode == 0 || ($random % 3) != 0)) begin
                in_valid <= 1;
                pixel_in <= img_x[k % N]; 
                d_in     <= img_d[k % N];
                in_last  <= ((k % N) == N - 1);
                k = k + 1;
                if (k == N) mode = 1; // Xong Frame 0 -> bat che do ngau nhien cho Frame 1
            end else begin
                in_valid <= 0; pixel_in <= 8'hxx; d_in <= 8'hxx; in_last <= 1'bx;
            end
        end
        out_ready <= (mode == 0) ? 1'b1 : (($random % 4) != 0);
    end

    // ---------------- Dich thu AXI-Stream (Slave) + Kiem tra ----------------
    integer nout = 0, errors = 0, n_last = 0, n_user = 0;
    reg       prev_stall = 0;
    reg [7:0] prev_data;
    reg       prev_last, prev_user;

    task fail(input [8*56-1:0] msg);
        begin
            errors = errors + 1;
            if (errors <= 20) $display("[%0t] LOI: %0s (pixel ra #%0d)", $time, msg, nout);
        end
    endtask

    always @(posedge clk) if (rst_n) begin
        // Kiem tra quy tac AXI: khi out_valid=1 ma out_ready=0, du lieu phai dung yen
        if (prev_stall) begin
            if (!out_valid) fail("out_valid bi ha khi chua duoc nhan");
            else if (out_data !== prev_data || out_last !== prev_last || out_user !== prev_user)
                fail("du lieu thay doi khi dang bi backpressure");
        end
        prev_stall <= out_valid && !out_ready;
        prev_data  <= out_data; prev_last <= out_last; prev_user <= out_user;

        if (out_valid && out_ready) begin
            if (out_data !== expv[nout]) begin
                fail("out_data sai");
                if (errors <= 20) $display("        DUT=%0d  MONG DOI=%0d", out_data, expv[nout]);
            end
            if (out_user !== ((nout % NO) == 0))      fail("out_user (TUSER) sai vi tri");
            if (out_last !== ((nout % NO) == NO - 1)) fail("out_last (TLAST) sai vi tri");
            
            // Ghi ket qua Frame 0 ra file .hex de danh gia bang Python
            if (nout < NO) $fdisplay(fd, "%02x", out_data);

            if (out_user) n_user = n_user + 1;
            if (out_last) n_last = n_last + 1;
            nout = nout + 1;
        end
    end

    integer t;
    initial begin
        // Nap 2 file anh .hex (da them vao Simulation Sources)
        $readmemh("clean_stripe.hex", img_x);
        $readmemh("noisy_stripe.hex", img_d);
        if (img_x[0] === 8'hxx || img_d[0] === 8'hxx) begin
            $display("LOI NGHIEM TRONG: Khong tim thay noisy05.hex hoac 05.hex!");
            $finish;
        end

        build_expected;
        fd = $fopen("filtered_stripe.hex", "w");
        $display("tb_lms_2d_top: Bat dau mo phong anh %0dx%0d, %0d frame (RESET_W=%0d, MU_LOG2=%0d)...", 
                 W, H, NF, RESET_W, MU_LOG2);

        #12;
        if (out_valid !== 1'b0 || in_ready !== 1'b1) fail("trang thai reset sai");
        #10 rst_n = 1;

        // Tang gioi han watchdog len 1,000,000 chu ky de du thoi gian chay 2 anh 256x256
        t = 0;
        while (nout < NF*NO && t < 1000000) begin @(posedge clk); t = t + 1; end
        repeat (10) @(posedge clk);
        $fclose(fd);

        if (nout !== NF*NO)   begin $display("LOI: nhan %0d pixel, mong doi %0d", nout, NF*NO); errors = errors + 1; end
        if (n_last !== NF)    begin $display("LOI: %0d TLAST, mong doi %0d", n_last, NF); errors = errors + 1; end
        if (n_user !== NF)    begin $display("LOI: %0d TUSER, mong doi %0d", n_user, NF); errors = errors + 1; end
        if (stall_full !== 0) begin $display("LOI: Frame 0 bi stall %0d chu ky (khong dat 1 pixel/clk)", stall_full); errors = errors + 1; end
        if (out_valid)        begin $display("LOI: con du lieu thua sau khi het frame"); errors = errors + 1; end

        if (errors == 0) $display("==> tb_lms_2d_top PASS (%0d pixel hop le, %0d frame anh 256x256)", nout, NF);
        else             $display("==> tb_lms_2d_top FAIL: %0d loi", errors);
        $finish;
    end
endmodule