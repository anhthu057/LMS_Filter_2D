//`timescale 1ns / 1ps
//// ============================================================================
//// tb_lms_2d_core.v - Kiem tra loi LMS (so hoc fixed-point)
////   TB co mo hinh tham chieu viet bang so nguyen 64 bit (giong lms_golden.py),
////   so sanh pixel_out MOI chu ky va 9 trong so (dut.weight[i]) sau MOI canh clock.
//// Kich ban:
////   T1 reset: trong so = {0,0,0,0,1,0,0,0,0}, y = pixel tam, e = 0 -> W khong doi
////   T2 bao hoa dau ra 255 / 0
////   T3 lam tron delta: e*x = -1 -> delta = 0 (khong troi am nhu phep >>> cu)
////   T4 bao hoa trong so o W_MAX va W_MIN
////   T5 update_en = 0 giu nguyen W; wreset uu tien hon update_en
////   T6 ngau nhien N chu ky (update_en, wreset ngau nhien)
//// Chay voi MU_LOG2 khac nhau:  iverilog -P tb_lms_2d_core.MU_LOG2=3 ...
////   (MU_LOG2=3 -> SHIFT=0, kiem tra nhanh generate NORND)
//// ============================================================================
//module tb_lms_2d_core;
//    parameter MU_LOG2  = 5;
//    parameter N_RANDOM = 20000;
//    localparam WW = 24, FRAC = 18;
//    localparam integer S = MU_LOG2 + 15 - FRAC;
//    localparam signed [63:0] WMAX = (64'sd1 <<< (WW-1)) - 1;
//    localparam signed [63:0] WMIN = -(64'sd1 <<< (WW-1));
//    localparam signed [63:0] ONE  = (64'sd1 <<< FRAC);

//    reg clk = 0; always #5 clk = ~clk;
//    reg rst_n = 0, update_en = 0, wreset = 0;
//    reg  [7:0] p [0:8];
//    reg  [7:0] d_in = 0;
//    wire [7:0] pixel_out;

//    lms_2d_core #(.DATA_WIDTH(8), .WEIGHT_W(WW), .FRAC(FRAC), .MU_LOG2(MU_LOG2)) dut (
//        .clk(clk), .rst_n(rst_n), .update_en(update_en), .wreset(wreset),
//        .p0(p[0]), .p1(p[1]), .p2(p[2]), .p3(p[3]), .p4(p[4]),
//        .p5(p[5]), .p6(p[6]), .p7(p[7]), .p8(p[8]),
//        .d_in(d_in), .pixel_out(pixel_out));

//    // ---------------- Mo hinh tham chieu ----------------
//    reg signed [63:0] rw [0:8];      // trong so tham chieu
//    reg signed [63:0] acc, y_ref, e_ref, g, dl, s;
//    integer i, k, errors = 0, checks = 0;

//    task ref_init; for (i = 0; i < 9; i = i + 1) rw[i] = (i == 4) ? ONE : 0; endtask

//    task ref_output;   // tinh y_ref, e_ref tu rw va dau vao hien tai
//        begin
//            acc = 0;
//            for (i = 0; i < 9; i = i + 1) acc = acc + rw[i] * $signed({56'd0, p[i]});
//            y_ref = (acc + (64'sd1 <<< (FRAC-1))) >>> FRAC;
//            if (y_ref < 0)   y_ref = 0;
//            if (y_ref > 255) y_ref = 255;
//            e_ref = $signed({56'd0, d_in}) - y_ref;
//        end
//    endtask

//    task ref_update;
//        for (i = 0; i < 9; i = i + 1) begin
//            g  = e_ref * $signed({56'd0, p[i]});
//            dl = (S > 0) ? ((g + (64'sd1 <<< (S-1))) >>> S) : (g <<< (-S));
//            s  = rw[i] + dl;
//            rw[i] = (s > WMAX) ? WMAX : (s < WMIN) ? WMIN : s;
//        end
//    endtask

//    task fail(input [8*48-1:0] msg);
//        begin
//            errors = errors + 1;
//            if (errors <= 20) $display("[%0t] LOI: %0s", $time, msg);
//        end
//    endtask

//    // Ghi truc tiep trong so vao DUT va mo hinh (de dung tinh huong bien)
//    task set_weight(input integer idx, input signed [63:0] val);
//        begin dut.weight[idx] = val[WW-1:0]; rw[idx] = val; end
//    endtask

//    // Mot chu ky: dat dau vao o negedge, kiem tra y truoc canh, kiem tra W sau canh
//    task cycle(input upd, input wrst);
//        begin
//            update_en = upd; wreset = wrst;
//            #1;
//            ref_output;
//            checks = checks + 1;
//            if (pixel_out !== y_ref[7:0]) begin
//                fail("pixel_out sai");
//                if (errors <= 20) $display("        DUT=%0d  REF=%0d", pixel_out, y_ref);
//            end
//            @(posedge clk);
//            if (wrst) ref_init; else if (upd) ref_update;
//            #1;
//            for (k = 0; k < 9; k = k + 1)
//                if ($signed(dut.weight[k]) !== rw[k]) begin
//                    fail("trong so sai");
//                    if (errors <= 20) $display("        w[%0d] DUT=%0d REF=%0d", k, $signed(dut.weight[k]), rw[k]);
//                end
//            @(negedge clk);
//        end
//    endtask

//    task set_x(input [7:0] a0, a1, a2, a3, a4, a5, a6, a7, a8);
//        begin p[0]=a0; p[1]=a1; p[2]=a2; p[3]=a3; p[4]=a4; p[5]=a5; p[6]=a6; p[7]=a7; p[8]=a8; end
//    endtask

//    integer n;
//    initial begin
//        $display("tb_lms_2d_core: MU_LOG2=%0d (SHIFT=%0d)", MU_LOG2, S);
//        set_x(0,0,0,0,0,0,0,0,0);
//        ref_init;
//        #12 rst_n = 1;
//        @(negedge clk);

//        // T1
//        $display("T1: gia tri khoi tao, y = pixel tam");
//        set_x(10, 20, 30, 40, 123, 60, 70, 80, 90); d_in = 123;
//        cycle(1, 0);
//        if (pixel_out !== 8'd123) fail("y != pixel tam khi W khoi tao");
//        for (k = 0; k < 9; k = k + 1) if (rw[k] !== ((k == 4) ? ONE : 0)) fail("e=0 nhung W thay doi");

//        // T2
//        $display("T2: bao hoa dau ra");
//        for (k = 0; k < 9; k = k + 1) set_weight(k, ONE);
//        set_x(255,255,255,255,255,255,255,255,255); d_in = 255;
//        cycle(0, 0);
//        if (pixel_out !== 8'd255) fail("khong bao hoa len 255");
//        for (k = 0; k < 9; k = k + 1) set_weight(k, -ONE);
//        cycle(0, 0);
//        if (pixel_out !== 8'd0) fail("khong bao hoa xuong 0");

//        // T3
//        if (S > 0) begin
//            $display("T3: lam tron delta (khong lech am)");
//            cycle(0, 1);                                  // wreset
//            set_x(1,0,0,0,1,0,0,0,0); d_in = 0;           // y = 1, e = -1, e*x = -1
//            cycle(1, 0);
//            if (rw[0] !== 0 || rw[4] !== ONE) fail("ref: delta(-1) phai = 0");
//        end

//        // T4
//        $display("T4: bao hoa trong so W_MAX / W_MIN");
//        cycle(0, 1);
//        set_weight(0, WMAX - 1); set_weight(1, -(WMAX - 1)); set_weight(4, 0);
//        set_x(255,255,0,0,0,0,0,0,0); d_in = 255;         // w0*x0 + w1*x1 = 0 -> y = 0, e = 255 > 0
//        cycle(1, 0);
//        if ($signed(dut.weight[0]) !== WMAX) fail("w0 khong bao hoa o W_MAX");
//        cycle(0, 1);
//        set_weight(0, WMAX - 1); set_weight(1, WMIN + 1); set_weight(2, 2*ONE); set_weight(4, 0);
//        set_x(255,255,100,0,0,0,0,0,0); d_in = 0;         // y ~ 200, e < 0
//        cycle(1, 0);
//        if ($signed(dut.weight[1]) !== WMIN) fail("w1 khong bao hoa o W_MIN");

//        // T5
//        $display("T5: update_en=0 giu W, wreset uu tien");
//        set_x(50,60,70,80,90,100,110,120,130); d_in = 10;
//        cycle(0, 0); cycle(0, 0);
//        cycle(1, 1);
//        for (k = 0; k < 9; k = k + 1) if (rw[k] !== ((k == 4) ? ONE : 0)) fail("wreset khong uu tien");

//        // T6
//        $display("T6: %0d chu ky ngau nhien", N_RANDOM);
//        for (n = 0; n < N_RANDOM; n = n + 1) begin
//            for (k = 0; k < 9; k = k + 1) p[k] = $random;
//            d_in = $random;
//            cycle(($random % 4) != 0, ($random % 500) == 0);
//        end

//        if (errors == 0) $display("==> tb_lms_2d_core PASS (%0d chu ky kiem tra)", checks);
//        else             $display("==> tb_lms_2d_core FAIL: %0d loi", errors);
//        $finish;
//    end
//enmodule




`timescale 1ns / 1ps

module tb_lms_2d_core;
    parameter MU_LOG2 = 6; // Toc do hoc mu = 2^-6 (co the doi 5, 6, 7 de thu do min)
    localparam W = 256, H = 256;
    localparam WW = 24, FRAC = 18;
    localparam integer S = MU_LOG2 + 15 - FRAC;
    localparam signed [63:0] WMAX = (64'sd1 <<< (WW-1)) - 1;
    localparam signed [63:0] WMIN = -(64'sd1 <<< (WW-1));
    localparam signed [63:0] ONE  = (64'sd1 <<< FRAC);

    reg clk = 0; 
    always #5 clk = ~clk;

    reg rst_n = 0, update_en = 0, wreset = 0;
    reg  [7:0] p [0:8];
    reg  [7:0] d_in = 0;
    wire [7:0] pixel_out;

    // Bo nho chua anh that 256x256
    reg [7:0] mem_noisy [0:W*H-1];
    reg [7:0] mem_clean [0:W*H-1];

    lms_2d_core #(
        .DATA_WIDTH(8), .WEIGHT_W(WW), .FRAC(FRAC), .MU_LOG2(MU_LOG2)
    ) dut (
        .clk(clk), .rst_n(rst_n), .update_en(update_en), .wreset(wreset),
        .p0(p[0]), .p1(p[1]), .p2(p[2]), 
        .p3(p[3]), .p4(p[4]), .p5(p[5]), 
        .p6(p[6]), .p7(p[7]), .p8(p[8]),
        .d_in(d_in), .pixel_out(pixel_out)
    );

    // ---------------- Mo hinh tham chieu 64-bit ----------------
    reg signed [63:0] rw [0:8];
    reg signed [63:0] acc, y_ref, e_ref, g, dl, s;
    integer i, k, r, c, fd, errors = 0, checks = 0;

    task ref_init; 
        for (i = 0; i < 9; i = i + 1) rw[i] = (i == 4) ? ONE : 0; 
    endtask

    task ref_output;
        begin
            acc = 0;
            for (i = 0; i < 9; i = i + 1) acc = acc + rw[i] * $signed({56'd0, p[i]});
            y_ref = (acc + (64'sd1 <<< (FRAC-1))) >>> FRAC;
            if (y_ref < 0)   y_ref = 0;
            if (y_ref > 255) y_ref = 255;
            e_ref = $signed({56'd0, d_in}) - y_ref;
        end
    endtask

    task ref_update;
        for (i = 0; i < 9; i = i + 1) begin
            g  = e_ref * $signed({56'd0, p[i]});
            dl = (S > 0) ? ((g + (64'sd1 <<< (S-1))) >>> S) : (g <<< (-S));
            s  = rw[i] + dl;
            rw[i] = (s > WMAX) ? WMAX : (s < WMIN) ? WMIN : s;
        end
    endtask

    task fail(input [8*48-1:0] msg);
        begin
            errors = errors + 1;
            if (errors <= 20) $display("[%0t] LOI: %0s", $time, msg);
        end
    endtask

    task set_weight(input integer idx, input signed [63:0] val);
        begin dut.weight[idx] = val[WW-1:0]; rw[idx] = val; end
    endtask

    task cycle(input upd, input wrst);
        begin
            update_en = upd; wreset = wrst;
            #1;
            ref_output;
            checks = checks + 1;
            if (pixel_out !== y_ref[7:0]) begin
                fail("pixel_out sai");
                if (errors <= 20) $display("        DUT=%0d  REF=%0d", pixel_out, y_ref);
            end
            @(posedge clk);
            if (wrst) ref_init; else if (upd) ref_update;
            #1;
            for (k = 0; k < 9; k = k + 1)
                if ($signed(dut.weight[k]) !== rw[k]) begin
                    fail("trong so sai");
                    if (errors <= 20) $display("        w[%0d] DUT=%0d REF=%0d", k, $signed(dut.weight[k]), rw[k]);
                end
            @(negedge clk);
        end
    endtask

    task set_x(input [7:0] a0, a1, a2, a3, a4, a5, a6, a7, a8);
        begin p[0]=a0; p[1]=a1; p[2]=a2; p[3]=a3; p[4]=a4; p[5]=a5; p[6]=a6; p[7]=a7; p[8]=a8; end
    endtask

    initial begin
        // Nap 2 file anh .hex (da tao o buoc truoc)
        $readmemh("noisy01.hex", mem_noisy);
        $readmemh("01.hex", mem_clean);
        if (mem_noisy[0] === 8'hxx || mem_clean[0] === 8'hxx) begin
            $display("LOI NGHIEM TRONG: Khong tim thay file .hex trong Simulation Sources!");
            $finish;
        end

        $display("tb_lms_2d_core: MU_LOG2=%0d (SHIFT=%0d)", MU_LOG2, S);
        set_x(0,0,0,0,0,0,0,0,0);
        ref_init;
        #12 rst_n = 1;
        @(negedge clk);

        // T1 - T5: Kiem tra nhanh cac tinh huong bien va bao hoa
        $display("T1-T5: Kiem tra reset, bao hoa dau ra/trong so, lam tron...");
        set_x(10, 20, 30, 40, 123, 60, 70, 80, 90); d_in = 123;
        cycle(1, 0);
        if (pixel_out !== 8'd123) fail("y != pixel tam khi W khoi tao");

        for (k = 0; k < 9; k = k + 1) set_weight(k, ONE);
        set_x(255,255,255,255,255,255,255,255,255); d_in = 255;
        cycle(0, 0);
        if (pixel_out !== 8'd255) fail("khong bao hoa len 255");

        cycle(0, 1); // wreset ve trang thai ban dau
        set_weight(0, WMAX - 1); set_weight(1, -(WMAX - 1)); set_weight(4, 0);
        set_x(255,255,0,0,0,0,0,0,0); d_in = 255;
        cycle(1, 0);
        if ($signed(dut.weight[0]) !== WMAX) fail("w0 khong bao hoa o W_MAX");

        // T6: Chay loc nhieu tren toan bo anh that 256x256 (64,516 cua so hop le)
        $display("T6: Loc nhieu anh that 256x256 va xuat file filtered_254x254.hex...");
        cycle(0, 1); // Dua bo trong so ve {0,0,0,0,1,0,0,0,0} truoc khi vao anh
        
        fd = $fopen("filtered01.hex", "w");
        for (r = 1; r < H - 1; r = r + 1) begin
            for (c = 1; c < W - 1; c = c + 1) begin
                set_x(
                    mem_noisy[(r-1)*W + (c-1)], mem_noisy[(r-1)*W + c], mem_noisy[(r-1)*W + (c+1)],
                    mem_noisy[r*W     + (c-1)], mem_noisy[r*W     + c], mem_noisy[r*W     + (c+1)],
                    mem_noisy[(r+1)*W + (c-1)], mem_noisy[(r+1)*W + c], mem_noisy[(r+1)*W + (c+1)]
                );
                d_in = mem_clean[r*W + c];
                #1;
                $fdisplay(fd, "%02x", pixel_out); // Ghi pixel da loc ra file
                cycle(1, 0);                       // Kiem tra bit-exact & cap nhat trong so
            end
        end
        $fclose(fd);

        // In 9 trong so cuoi cung sau khi hoc xong buc anh (quy doi ve so thuc)
        $display("Trong so cuoi cung (Q6.18 -> thuc):");
        for (k = 0; k < 9; k = k + 1)
            $display("  w[%0d] = %0d (%.4f)", k, $signed(dut.weight[k]), $itor($signed(dut.weight[k])) / 262144.0);

        if (errors == 0) $display("==> tb_lms_2d_core PASS (%0d chu ky kiem tra khop 100%%)", checks);
        else             $display("==> tb_lms_2d_core FAIL: %0d loi", errors);
        $finish;
    end
endmodule