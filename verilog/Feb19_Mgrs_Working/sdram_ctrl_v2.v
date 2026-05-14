`timescale 1ns / 1ps

//===================================================================
//  Simple 32-bit SDRAM Controller - Burst=8 + Auto-precharge + Refresh
//  Target: typical SDR SDRAM (IS42S16400 / MT48LC4M32 / similar)
//  2025-2026 style, single transaction, educational/reference level
//
// Template created by Grok
// Working model by D. Gruenbacher, burst length = 8
// Adjustments for measured timing delays (Feb 12, 2026)
//
//===================================================================

module sdram_controller_32bit
(
    input  wire         clk,                // typically 100–133 MHz
    input  wire         rst_n,				// reset, active low

    // User interface (simple handshake - single transaction)
    input  wire         wr_req,				// write request(active high) for 1-clk period
    input  wire         rd_req,				// read request(active high) for 1-clk period
    input  wire [23:0]  addr,               // 24-bit addr → 16M words of 4 bytes each (64 MB)
    input  wire [31:0]  wr_data,			//  Write data (active on wr_req, update on wr_next
    output reg  [31:0]  rd_data,			// Read data (active and updated on rd_valid)
    output reg          rd_valid,			// Indicates new data on rd_data
    output reg          busy,				// Indicates controller is busy, both rd_req and wr_req ignored
	output reg			wr_next,			// Tells user when to update wr_data

    // SDRAM Pins
    output reg  [12:0]  sdram_a,		// Address
    output reg  [1:0]   sdram_ba,		// Bank address
    inout  wire [31:0]  sdram_dq,		// bi-directional data interface
    output reg  [3:0]   sdram_dqm,      // Data byte masks, usually 4'b0000 for full 32-bit
    output reg          sdram_cke,		// clock enable
    output reg          sdram_cs_n,		// chip select
    output reg          sdram_ras_n,	// row address strobe
    output reg          sdram_cas_n,	// column address strobe
    output reg          sdram_we_n		// write enable
);

//========================================================================
// Parameters - example for ~100 MHz (adjust according to your datasheet)
//========================================================================
parameter real  CLK_PERIOD      = 10.0;     // ns (use 7.519 for 133 MHz)

parameter       CAS_LATENCY     = 3;		// According to datasheet
parameter       BURST_LENGTH    = 8;

localparam      tRP             = 18;       // ns
localparam      tRCD            = 18;
localparam      tRC             = 60;
localparam      tRAS            = 42;
localparam      tWR             = 15;
localparam      tMRD            = 2;        // cycles

localparam      REFRESH_PERIOD  = 7800;     // ns   (~64ms / 8192)

// Derived cycle counts (ceiling)
localparam [5:0] CNT_tRP   = (tRP   + CLK_PERIOD-1) / CLK_PERIOD;
localparam [5:0] CNT_tRCD  = (tRCD  + CLK_PERIOD-1) / CLK_PERIOD;
localparam [5:0] CNT_tRC   = (tRC   + CLK_PERIOD-1) / CLK_PERIOD;
localparam [5:0] CNT_tRAS  = (tRAS  + CLK_PERIOD-1) / CLK_PERIOD;
localparam [5:0] CNT_tWR   = (tWR   + CLK_PERIOD-1) / CLK_PERIOD;
localparam [5:0] CNT_tMRD  = tMRD;

// Refresh counter period in cycles
localparam [12:0] REFRESH_CNT_MAX = (REFRESH_PERIOD + CLK_PERIOD-1) / CLK_PERIOD;

//========================================================================
// States
//========================================================================
localparam [4:0]
    S_INIT              = 5'd0,
    S_INIT_WAIT_200US   = 5'd1,
    S_INIT_PRE_ALL      = 5'd2,
    S_INIT_WAIT_tRP     = 5'd3,
    S_INIT_REF1         = 5'd4,
    S_INIT_REF_WAIT1     = 5'd5,
    S_INIT_REF2         = 5'd6,
	S_INIT_REF_WAIT2     = 5'd19,
    S_INIT_LOAD_MODE    = 5'd7,
    S_INIT_WAIT_MRD     = 5'd8,
    S_IDLE              = 5'd9,
    S_ACTIVATE          = 5'd10,
    S_WAIT_tRCD         = 5'd11,
    S_READ_CMD          = 5'd12,
    S_READ_BURST        = 5'd13,
    S_WRITE_CMD         = 5'd14,
    S_WRITE_BURST       = 5'd15,
    S_WRITE_WAIT_TWR    = 5'd16,
    S_AUTO_REFRESH      = 5'd17,
    S_REFRESH_WAIT      = 5'd18;

//========================================================================
// Registers
//========================================================================
reg  [4:0]      state /* synthesis syn_preserve=1 */;

reg  [15:0]     init_timer;
reg  [5:0]      wait_cnt;

reg  [12:0]     refresh_timer;
reg             refresh_req;

reg  [23:0]     addr_latch;
reg             is_write;
reg  [3:0]      burst_cnt;

reg  [31:0]     dq_out_reg;
reg             dq_oe;

// Address mapping (example for 4Mx8x4 banks → 32-bit wide)
wire [1:0]   bank  = addr_latch[23:22];
wire [12:0]  row   = addr_latch[21:9];
wire [8:0]   col   = addr_latch[8:0];

// Bidirectional data bus
assign sdram_dq = dq_oe ? dq_out_reg : 32'hZZZZ_ZZZZ;

//========================================================================
// Refresh counter
//========================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        refresh_timer <= REFRESH_CNT_MAX;
        refresh_req   <= 1'b0;
    end
    else begin
        if (refresh_timer == 0) begin
            refresh_timer <= REFRESH_CNT_MAX;
            refresh_req   <= 1'b1;
        end
        else begin
            refresh_timer <= refresh_timer - 1'b1;
        end

        if (state == S_AUTO_REFRESH)
            refresh_req <= 1'b0;
    end
end

//========================================================================
// Main FSM
//========================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state           <= S_INIT;
        sdram_cke       <= 0;
        sdram_cs_n      <= 1;
        sdram_ras_n     <= 1;
        sdram_cas_n     <= 1;
        sdram_we_n      <= 1;
        sdram_dqm       <= 4'b0000;
        dq_oe           <= 1'b0;
        busy            <= 1'b1;
        rd_valid        <= 1'b0;
        init_timer      <= 16'd0;
        wait_cnt        <= 6'd0;
        burst_cnt       <= 4'd0;
		sdram_a			<= 13'd0;
		wr_next			<= 1'b0;
    end
    else begin

        rd_valid <= 1'b0;   // default: single cycle pulse

        case (state)

            //────────────────────────────── Initialization ──────────────────────────────
            S_INIT: begin
                sdram_cke   <= 0;
                init_timer  <= 20000;   // ~200 μs @ 100MHz
                state       <= S_INIT_WAIT_200US;
            end

            S_INIT_WAIT_200US: begin
                if (init_timer == 0) begin
                    sdram_cke <= 1;
                    state     <= S_INIT_PRE_ALL;
                end
                else
                    init_timer <= init_timer - 1;
            end

            S_INIT_PRE_ALL: begin
                sdram_cs_n  <= 0;
                sdram_ras_n <= 0;
				sdram_cas_n <= 1;
                sdram_we_n  <= 0;
                sdram_a[10] <= 1;           // all banks precharge
                state       <= S_INIT_WAIT_tRP;
                wait_cnt    <= CNT_tRP;
            end

            S_INIT_WAIT_tRP: begin
                if (wait_cnt == 0) state <= S_INIT_REF1;
                else               wait_cnt <= wait_cnt - 1;
            end

            S_INIT_REF1: begin
                sdram_ras_n <= 0;
                sdram_cas_n <= 0;
                sdram_we_n  <= 1;           // auto-refresh
                state       <= S_INIT_REF_WAIT1;
                wait_cnt    <= CNT_tRC;
            end

            S_INIT_REF_WAIT1: begin  // DG:  addition of second ref_wait state
                if (wait_cnt == 0) begin
                        state <= S_INIT_REF2;
                    
                end
                else
                    wait_cnt <= wait_cnt - 1;
            end

            S_INIT_REF2: begin  // DG:   updated based on above
                sdram_ras_n <= 0;
                sdram_cas_n <= 0;
                sdram_we_n  <= 1;
                state       <= S_INIT_REF_WAIT2;
                wait_cnt    <= CNT_tRC;
            end

           S_INIT_REF_WAIT2: begin  
                if (wait_cnt == 0) begin
                        state <= S_INIT_LOAD_MODE;
                    
                end
                else
                    wait_cnt <= wait_cnt - 1;
            end

            S_INIT_LOAD_MODE: begin
                sdram_cs_n  <= 0;
                sdram_ras_n <= 0;
                sdram_cas_n <= 0;
                sdram_we_n  <= 0;
                sdram_ba    <= 2'b00;
               /* DG_comment sdram_a     <= { 3'b000,        // reserved
                                 1'b0,          // normal operation
                                 2'b00,         // sequential burst
                                 3'b111,        // BL=8
                                 CAS_LATENCY[2:0],
                                 1'b0,          // write burst = single
                                 2'b00 };       // reserved  */
               sdram_a     <= { 5'b00000,        // reserved
                                 1'b0,          // write burst
                                 2'b00,         // reserved
                                 CAS_LATENCY[2:0],
								 1'b0,			// Burst type = sequential
                                 3'b011};        // BL=8

				state       <= S_INIT_WAIT_MRD;
                wait_cnt    <= CNT_tMRD;
            end

            S_INIT_WAIT_MRD: begin
                if (wait_cnt == 0)
                    state <= S_IDLE;
                else
                    wait_cnt <= wait_cnt - 1;
            end

            //────────────────────────────── Normal operation ──────────────────────────────
            S_IDLE: begin
                sdram_cs_n  <= 1;
                dq_oe       <= 0;
                busy        <= 0;
                rd_valid    <= 0;

                if (refresh_req)
					begin
                    state <= S_AUTO_REFRESH;
					busy <= 1;
					end
                else if (wr_req || rd_req) begin
                    addr_latch  <= addr;
                    is_write    <= wr_req;
                    busy        <= 1;
                    state       <= S_ACTIVATE;
                end
            end

            S_ACTIVATE: begin
                sdram_cs_n  <= 0;
                sdram_ras_n <= 0;
                sdram_cas_n <= 1;
                sdram_we_n  <= 1;
                sdram_ba    <= bank;
                sdram_a     <= row;
                state       <= S_WAIT_tRCD;
                wait_cnt    <= CNT_tRCD;
            end

            S_WAIT_tRCD: begin
				// Added by DG for NOP
				sdram_cs_n  <= 0;
                sdram_ras_n <= 1;
                sdram_cas_n <= 1;
                sdram_we_n  <= 1;
				// End of added DG code
				
                if (wait_cnt == 0)
					begin
                    state <= is_write ? S_WRITE_CMD : S_READ_CMD;
					wr_next <= is_write ? 1'b1 : 1'b0; 
					end
                else
                    wait_cnt <= wait_cnt - 1;
            end

            //────────────────────────────── READ path ──────────────────────────────
            S_READ_CMD: begin
                sdram_ras_n <= 1;
                sdram_cas_n <= 0;
                sdram_we_n  <= 1;
                sdram_a     <= {4'b0010, col};  // A10=1 → auto-precharge
                sdram_ba    <= bank;
                burst_cnt   <= 4'd0;
                state       <= S_READ_BURST;
            end

            S_READ_BURST: begin
			
				// NOP
				sdram_cs_n  <= 0;
                sdram_ras_n <= 1;
                sdram_cas_n <= 1;
                sdram_we_n  <= 1;
				
                burst_cnt <= burst_cnt + 1;

                if (burst_cnt >= (CAS_LATENCY)) begin // DG:  remove -1
                    rd_data  <= sdram_dq;
                    rd_valid <= 1'b1;
                end

                if (burst_cnt == (CAS_LATENCY + BURST_LENGTH-1))
                    state <= S_IDLE;
            end

            //────────────────────────────── WRITE path ──────────────────────────────
            S_WRITE_CMD: begin
                sdram_ras_n <= 1;
                sdram_cas_n <= 0;
                sdram_we_n  <= 0;
                sdram_a     <= {4'b0010, col};  // A10=1 → auto-precharge
                sdram_ba    <= bank;
                dq_oe       <= 1;
                dq_out_reg  <= wr_data;
                burst_cnt   <= 4'd0;
				wr_next		<= 1'b1;
                state       <= S_WRITE_BURST;
            end

            S_WRITE_BURST: begin
			
				// DG:  add NOP
				sdram_cs_n  <= 0;
                sdram_ras_n <= 1;
                sdram_cas_n <= 1;
                sdram_we_n  <= 1;
				wait_cnt <= CNT_tWR + CNT_tRP;
				
                burst_cnt <= burst_cnt + 1;
				
				if(burst_cnt >= BURST_LENGTH-2)
					wr_next <= 1'b0;
					

                // Note: this simple version assumes new wr_data arrives every cycle
                // Real design usually uses small FIFO
                dq_out_reg <= wr_data;

                if (burst_cnt == (BURST_LENGTH-1+4))  // DG:   change from -2
                    dq_oe <= 1'b0;  // release one cycle earlier

                if (burst_cnt == (BURST_LENGTH-1+4))
                    state <= S_WRITE_WAIT_TWR;
            end

            S_WRITE_WAIT_TWR: begin
                if (wait_cnt == 0)
                    state <= S_IDLE;
                else
                    wait_cnt <= wait_cnt - 1;
            end

            //────────────────────────────── Refresh ──────────────────────────────
            S_AUTO_REFRESH: begin
                sdram_cs_n  <= 0;
                sdram_ras_n <= 0;
                sdram_cas_n <= 0;
                sdram_we_n  <= 1;
                state       <= S_REFRESH_WAIT;
                wait_cnt    <= CNT_tRC;
            end

            S_REFRESH_WAIT: begin
                if (wait_cnt == 0)
                    state <= S_IDLE;
                else
                    wait_cnt <= wait_cnt - 1;
            end

            default: state <= S_INIT;
        endcase
    end
end

endmodule