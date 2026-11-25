`timescale 1ns / 1ps
// ============================================================================
// tb_lms_axi_wrapper.v - Kiem tra muc he thong voi anh that 256x256
//   Can 3 file hex tao boi:  python lms_golden.py 05.png noisy05.png --hex
//     noisy.hex, clean.hex : anh dau vao (moi dong 1 pixel)
//     golden.hex           : ket qua mong doi 254x254 tu mo hinh bit-accurate
//   Mo phong hanh vi AXI DMA:
//     * MM2S: TDATA = {clean, noisy}, TLAST o pixel cuoi, TVALID ngat quang
//     * S2MM: TREADY ngau nhien (backpressure)
//   Kiem tra: so sanh tung pixel voi golden, TLAST/TUSER, quy tac AXI-Stream,
//             ghi ket qua ra filtered05.hex (dung voi evaluate_lms.py)
//   STALL_PCT = 0 -> TVALID/TREADY luon 1, do thong luong (phai ~1 pixel/clk)
// ============================================================================
module tb_lms_axi_wrapper;
    parameter STALL_PCT = 25;            // % chu ky TVALID / TREADY bi ha
    parameter FRAMES    = 2;
    localparam W = 256, H = 256, N = W*H, NO = (W-2)*(H-2);

    reg clk = 0; always #5 clk = ~clk;   // 100 MHz
    reg rstn = 0;

    reg  [7:0] noisy [0:N-1], clean [0:N-1], gold [0:NO-1];
    reg  [15:0] s_tdata = 0; reg s_tvalid = 0, s_tlast = 0;
    wire s_tready;
    wire [7:0] m_tdata; wire m_tvalid, m_tlast, m_tuser;
    reg  m_tready = 0;

    lms_axi_wrapper #(.IMG_WIDTH(W), .IMG_HEIGHT(H), .MU_LOG2(5)) dut (
        .ACLK(clk), .ARESETN(rstn),
        .S_AXIS_TDATA(s_tdata), .S_AXIS_TVALID(s_tvalid), .S_AXIS_TREADY(s_tready), .S_AXIS_TLAST(s_tlast),
        .M_AXIS_TDATA(m_tdata), .M_AXIS_TVALID(m_tvalid), .M_AXIS_TREADY(m_tready),
        .M_AXIS_TLAST(m_tlast), .M_AXIS_TUSER(m_tuser));

    integer errors = 0;
    task fail(input [8*56-1:0] msg);
        begin
            errors = errors + 1;
            if (errors <= 20) $display("[%0t] LOI: %0s", $time, msg);
        end
    endtask

    // ---------------- MM2S: nguon AXI-Stream ----------------
    integer k = 0;
    always @(posedge clk) if (rstn) begin
        if (!s_tvalid || s_tready) begin
            if (k < FRAMES*N && ($unsigned($random) % 100) >= STALL_PCT) begin
                s_tvalid <= 1'b1;
                s_tdata  <= {clean[k % N], noisy[k % N]};
                s_tlast  <= ((k % N) == N-1);
                k = k + 1;
            end else begin
                s_tvalid <= 1'b0; s_tdata <= 16'hxxxx; s_tlast <= 1'bx;
            end
        end
        m_tready <= ($unsigned($random) % 100) >= STALL_PCT;
    end

    // ---------------- S2MM: dich AXI-Stream + kiem tra ----------------
    integer nout = 0, nerr = 0, nlast = 0, nuser = 0, f;
    integer t_first = 0, t_last = 0, cyc = 0;
    reg prev_stall = 0; reg [7:0] p_data; reg p_last, p_user;

    always @(posedge clk) begin
        cyc = cyc + 1;
        if (rstn) begin
            if (prev_stall && (!m_tvalid || m_tdata !== p_data || m_tlast !== p_last || m_tuser !== p_user))
                fail("vi pham AXI: M_AXIS thay doi khi TVALID=1 va TREADY=0");
            prev_stall <= m_tvalid && !m_tready;
            p_data <= m_tdata; p_last <= m_tlast; p_user <= m_tuser;

            if (m_tvalid && m_tready) begin
                if (nout == 0) t_first = cyc;
                t_last = cyc;
                if (nout < NO) $fwrite(f, "%02x\n", m_tdata);
                if (m_tdata !== gold[nout % NO]) begin
                    nerr = nerr + 1;
                    if (nerr <= 5) $display("  pixel %0d: DUT=%02x GOLDEN=%02x", nout, m_tdata, gold[nout % NO]);
                end
                if (m_tlast !== ((nout % NO) == NO-1)) fail("TLAST sai vi tri");
                if (m_tuser !== ((nout % NO) == 0))    fail("TUSER sai vi tri");
                if (m_tlast) nlast = nlast + 1;
                if (m_tuser) nuser = nuser + 1;
                nout = nout + 1;
            end
        end
    end

    integer t;
    initial begin
        $readmemh("noisy.hex", noisy);
        $readmemh("clean.hex", clean);
        $readmemh("golden.hex", gold);
        if (^noisy[N-1] === 1'bx || ^gold[NO-1] === 1'bx) begin
            $display("LOI: khong doc duoc file hex - chay 'python lms_golden.py ... --hex' truoc");
            $finish;
        end
        f = $fopen("filtered05.hex", "w");
        $display("tb_lms_axi_wrapper: %0d frame 256x256, STALL_PCT=%0d%%", FRAMES, STALL_PCT);

        #22 rstn = 1;
        t = 0;
        while (nout < FRAMES*NO && t < FRAMES*N*20) begin @(posedge clk); t = t + 1; end
        $fclose(f);

        if (nout !== FRAMES*NO) begin $display("LOI: TIMEOUT, moi nhan %0d/%0d pixel", nout, FRAMES*NO); errors = errors + 1; end
        if (nerr  !== 0)        begin $display("LOI: %0d pixel khac golden", nerr); errors = errors + 1; end
        if (nlast !== FRAMES)   begin $display("LOI: %0d TLAST, mong doi %0d", nlast, FRAMES); errors = errors + 1; end
        if (nuser !== FRAMES)   begin $display("LOI: %0d TUSER, mong doi %0d", nuser, FRAMES); errors = errors + 1; end

        $display("Pixel ra: %0d | khac golden: %0d | TLAST: %0d | TUSER: %0d", nout, nerr, nlast, nuser);
        $display("Thoi gian tu pixel ra dau den cuoi: %0d chu ky clock", t_last - t_first);
        if (errors == 0) $display("==> tb_lms_axi_wrapper PASS");
        else             $display("==> tb_lms_axi_wrapper FAIL: %0d loi", errors);
        $finish;
    end
endmodule