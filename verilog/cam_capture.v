//cam_capture.v
//ECE641 Project 4
//Camera frame capture module
//
// Reset convention: ar is active LOW (ar=0 means reset, ar=1 means run)
// Pass ~ar from golden_top since reference uses active-high ar=KEY[3]
//
// Waits for record_req (~KEY[1], active high when pressed), then on the
// next vsync captures one full 640x480 frame from CAMERA_D8M VGA output
// and pushes it into the sdram_mgr write FIFOs in 512 word bursts.

`timescale 1 ns / 1 ns

module cam_capture(ar, clk, record_req, bank_sel,
                   VGA_CLK, VGA_HS, VGA_VS, VGA_DE,
                   VGA_R, VGA_G, VGA_B,
                   cam_wr_addr_valid, cam_wr_addr,
                   cam_wr_data_valid, cam_wr_data);

    input ar;               // active LOW reset (ar=0 resets, ar=1 runs)
    input clk;              // system clock (sdram_ctrl_clk ~100MHz)
    input record_req;       // ~KEY[1], high when button pressed
    input [1:0] bank_sel;   // SW[9:8]

    input VGA_CLK;
    input VGA_HS;
    input VGA_VS;
    input VGA_DE;
    input [7:0] VGA_R;
    input [7:0] VGA_G;
    input [7:0] VGA_B;

    output reg cam_wr_addr_valid;
    output reg [23:0] cam_wr_addr;
    output reg cam_wr_data_valid;
    output reg [31:0] cam_wr_data;

    parameter WORDS_PER_BURST  = 10'd512;
    parameter BURSTS_PER_FRAME = 10'd600;  // 640*480/512 = 600

    // VGA_CLK domain

    // Sync record_req into VGA_CLK domain
    reg record_req_s1_vga, record_req_s2_vga;
    always @(posedge VGA_CLK or negedge ar)
        if(~ar)
        begin
            record_req_s1_vga <= 1'b0;
            record_req_s2_vga <= 1'b0;
        end
        else
        begin
            record_req_s1_vga <= record_req;
            record_req_s2_vga <= record_req_s1_vga;
        end

    // Vsync edge detection
    reg vs_prev_vga;
    wire vs_posedge_vga;

    always @(posedge VGA_CLK or negedge ar)
        if(~ar)
            vs_prev_vga <= 1'b0;
        else
            vs_prev_vga <= VGA_VS;

    assign vs_posedge_vga = VGA_VS & ~vs_prev_vga;

    // Latch record request until vsync
    reg record_pending;

    always @(posedge VGA_CLK or negedge ar)
        if(~ar)
            record_pending <= 1'b0;
        else if(record_req_s2_vga)
            record_pending <= 1'b1;
        else if(vs_posedge_vga && record_pending)
            record_pending <= 1'b0;

    // Capture active flag and pixel packing
    reg capture_active;
    reg [31:0] pix_word;
    reg cap_wrreq;
    wire cap_wrfull;

    always @(posedge VGA_CLK or negedge ar)
        if(~ar)
        begin
            capture_active <= 1'b0;
            cap_wrreq      <= 1'b0;
            pix_word       <= 32'd0;
        end
        else
        begin
            cap_wrreq <= 1'b0;

            if(vs_posedge_vga && record_pending)
                capture_active <= 1'b1;

            if(vs_posedge_vga && capture_active && !record_pending)
                capture_active <= 1'b0;

            if(capture_active && VGA_DE && !cap_wrfull)
            begin
                pix_word  <= {VGA_R, VGA_G, VGA_B, 8'h00};
                cap_wrreq <= 1'b1;
            end
        end

    // Capture FIFO: VGA_CLK write, clk read

    wire cap_rdempty;
    wire [10:0] cap_usedw;
    reg cap_rdreq;
    wire [31:0] cap_q;

    fifo_32_dc cap_fifo (
        .wrclk  (VGA_CLK),
        .rdclk  (clk),
        .aclr   (~ar),
        .wrreq  (cap_wrreq),
        .rdreq  (cap_rdreq),
        .data   (pix_word),
        .q      (cap_q),
        .wrempty(),
        .wrfull (cap_wrfull),
        .rdempty(cap_rdempty),
        .rdfull (),
        .usedw  (cap_usedw)
    );

    // System clock domain: drain FIFO and issue write requests

    // Sync capture_active into clk domain
    reg cap_active_s1, cap_active_s2;
    always @(posedge clk or negedge ar)
        if(~ar)
        begin
            cap_active_s1 <= 1'b0;
            cap_active_s2 <= 1'b0;
        end
        else
        begin
            cap_active_s1 <= capture_active;
            cap_active_s2 <= cap_active_s1;
        end

    parameter [2:0] CAP_Idle     = 3'd0,
                    CAP_WaitFull = 3'd1,
                    CAP_SendAddr = 3'd2,
                    CAP_SendData = 3'd3,
                    CAP_Done     = 3'd4;

    reg [2:0]  cap_cs;
    reg [9:0]  cap_burst_cnt;
    reg [9:0]  cap_burst_num;
    reg [23:0] cap_base_addr;

    always @(posedge clk or negedge ar)
        if(~ar)
        begin
            cap_cs            <= CAP_Idle;
            cap_burst_cnt     <= 10'd0;
            cap_burst_num     <= 10'd0;
            cap_base_addr     <= 24'd0;
            cap_rdreq         <= 1'b0;
            cam_wr_addr_valid <= 1'b0;
            cam_wr_addr       <= 24'd0;
            cam_wr_data_valid <= 1'b0;
            cam_wr_data       <= 32'd0;
        end
        else
        begin
            cam_wr_addr_valid <= 1'b0;
            cam_wr_data_valid <= 1'b0;
            cap_rdreq         <= 1'b0;

            case(cap_cs)

                CAP_Idle:
                begin
                    if(cap_active_s2)
                    begin
                        cap_base_addr <= {bank_sel, 22'd0};
                        cap_burst_num <= 10'd0;
                        cap_burst_cnt <= 10'd0;
                        cap_cs        <= CAP_WaitFull;
                    end
                end

                CAP_WaitFull:
                begin
                    if(!cap_active_s2 && cap_rdempty)
                        cap_cs <= CAP_Done;
                    else if(cap_usedw >= 11'd512)
                    begin
                        cam_wr_addr       <= cap_base_addr;
                        cam_wr_addr_valid <= 1'b1;
                        cap_cs            <= CAP_SendAddr;
                    end
                end

                CAP_SendAddr:
                begin
                    cap_burst_cnt <= 10'd0;
                    cap_cs        <= CAP_SendData;
                end

                CAP_SendData:
                begin
                    if(!cap_rdempty)
                    begin
                        cam_wr_data       <= cap_q;
                        cam_wr_data_valid <= 1'b1;
                        cap_rdreq         <= 1'b1;

                        if(cap_burst_cnt < WORDS_PER_BURST - 1)
                            cap_burst_cnt <= cap_burst_cnt + 10'd1;
                        else
                        begin
                            cap_burst_cnt <= 10'd0;
                            cap_base_addr <= cap_base_addr + 24'd512;
                            cap_burst_num <= cap_burst_num + 10'd1;

                            if(cap_burst_num < BURSTS_PER_FRAME - 1)
                                cap_cs <= CAP_WaitFull;
                            else
                                cap_cs <= CAP_Done;
                        end
                    end
                end

                CAP_Done:
                begin
                    if(!cap_active_s2)
                        cap_cs <= CAP_Idle;
                end

                default:
                    cap_cs <= CAP_Idle;

            endcase
        end

endmodule