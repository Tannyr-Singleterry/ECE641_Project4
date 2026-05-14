// Samsung SDRAM K4M51323PC model from AI (Grok)

`timescale 1ns/1ps

module sdram_model (
    input         CLK,
    input         CKE,
    input         CS_N,
    input         RAS_N,
    input         CAS_N,
    input         WE_N,
    input  [1:0]  BA,
    input [12:0]  ADDR,
    inout [31:0]  DQ,
    input  [3:0]  DQM
);

    // ------------------------------------------------------------
    // Internal Geometry
    // ------------------------------------------------------------
    localparam BANKS = 4;
    localparam ROWS  = 4096;
    localparam COLS  = 1024;

    // ------------------------------------------------------------
    // JEDEC Timing (cycles)
    // ------------------------------------------------------------
    localparam tRCD  = 2;
    localparam tRP   = 2;
    localparam tRAS  = 4;
    localparam tRC   = 6;
    localparam tWR   = 2;
    localparam tRFC  = 8;  // 80 ns
    localparam tREFI = 780;

    // ------------------------------------------------------------
    // Memory Array
    // ------------------------------------------------------------
    reg [31:0] mem [0:BANKS-1][0:ROWS-1][0:COLS-1];

    // ------------------------------------------------------------
    // Mode Register (MRS)
    // ------------------------------------------------------------
    integer burst_length;
    integer cas_latency;
    reg     burst_type_interleave;

    // ------------------------------------------------------------
    // Bank and Timing State
    // ------------------------------------------------------------
    reg [11:0] active_row [0:BANKS-1];
    reg        bank_open  [0:BANKS-1];

    integer act_timer [0:BANKS-1];
    integer pre_timer [0:BANKS-1];
    integer wr_timer  [0:BANKS-1];

    // ------------------------------------------------------------
    // Refresh State
    // ------------------------------------------------------------
    integer refresh_timer;
    integer rfc_timer;
    reg     refresh_busy;

    // ------------------------------------------------------------
    // Data Path
    // ------------------------------------------------------------
    reg [31:0] dq_out;
    reg        dq_oe;
    assign DQ = dq_oe ? dq_out : 32'bz;

    // Read pipeline
    // DG  integer rd_pipe [0:3];
	reg [3:0] rd_pipe;
    integer rd_count, wr_count;
    reg [1:0] rd_bank, wr_bank;
    reg [9:0] rd_col, wr_col;
    wire      auto_pre = ADDR[10];

    // ------------------------------------------------------------
    // Command Decode
    // ------------------------------------------------------------
    wire cmd_act = ~CS_N & ~RAS_N &  CAS_N &  WE_N;
    wire cmd_rd  = ~CS_N &  RAS_N & ~CAS_N &  WE_N;
    wire cmd_wr  = ~CS_N &  RAS_N & ~CAS_N & ~WE_N;
    wire cmd_pre = ~CS_N & ~RAS_N &  CAS_N & ~WE_N;
    wire cmd_mrs = ~CS_N & ~RAS_N & ~CAS_N & ~WE_N;
    wire cmd_ref = ~CS_N & ~RAS_N & ~CAS_N &  WE_N;

    integer i;

    // ------------------------------------------------------------
    // Increment timers
    // ------------------------------------------------------------
    always @(posedge CLK) begin
        // if (!CKE) disable dq_oe;  // Commented out by DG due to modelsim error

        // global refresh interval
        if (refresh_timer < tREFI) refresh_timer <= refresh_timer + 1;

        // refresh busy window
        if (refresh_busy && rfc_timer < tRFC) rfc_timer <= rfc_timer + 1;
    end

    // per-bank timers
    always @(posedge CLK) begin
        for (i = 0; i < BANKS; i = i + 1) begin
            act_timer[i] <= act_timer[i] + 1;
            pre_timer[i] <= pre_timer[i] + 1;
            wr_timer[i]  <= wr_timer[i]  + 1;
        end
    end

    // ------------------------------------------------------------
    // Main SDRAM engine
    // ------------------------------------------------------------
    always @(posedge CLK) begin
        dq_oe <= 0;

        // check refresh interval
        if (refresh_timer > tREFI)
            $error("tREFI violation: refresh missed");

        // block commands during refresh busy
        if (refresh_busy && rfc_timer < tRFC)
            if (cmd_act || cmd_rd || cmd_wr || cmd_pre)
                $error("Command during tRFC");

        // end refresh busy
        if (refresh_busy && rfc_timer >= tRFC)
            refresh_busy <= 0;

        // -----------------------------
        // Mode Register Set (MRS)
        // -----------------------------
        if (cmd_mrs) begin
            cas_latency          <= ADDR[6:4];
            burst_type_interleave<= ADDR[3];
            case (ADDR[2:0])
                3'b000: burst_length <= 1;
                3'b001: burst_length <= 2;
                3'b010: burst_length <= 4;
                3'b011: burst_length <= 8;
                default: burst_length <= COLS;
            endcase
        end

        // -----------------------------
        // AUTO REFRESH
        // -----------------------------
        if (cmd_ref) begin
            // all banks must be idle
            for (i = 0; i < BANKS; i = i + 1)
                if (bank_open[i])
                    $error("REFRESH with bank active");

            refresh_busy  <= 1;
            refresh_timer <= 0;
            rfc_timer     <= 0;
        end

        // -----------------------------
        // ACTIVATE
        // -----------------------------
        if (cmd_act) begin
            if (bank_open[BA] && act_timer[BA] < tRC)
                $error("tRC violation on activate");
            if (pre_timer[BA] < tRP)
                $error("tRP violation on activate");

            bank_open[BA]   <= 1;
            active_row[BA]  <= ADDR[11:0];
            act_timer[BA]   <= 0;
        end

        // -----------------------------
        // READ
        // -----------------------------
        if (cmd_rd) begin
            if (!bank_open[BA])
                $error("READ to closed bank");
            if (act_timer[BA] < tRCD)
                $error("tRCD violation on READ");

            rd_bank  <= BA;
            rd_col   <= ADDR[9:0];
            rd_count <= burst_length;
			if(cas_latency == 3)
				rd_pipe <= 4'b0011;
			else				// cas_latency = 2
				rd_pipe <= 4'b0111;
				
            /* for (i = 0; i < 4; i = i + 1)
                rd_pipe[i] <= (i == cas_latency-1);
				*/
        end
		else
		  begin
        // -----------------------------
        // READ PIPELINE
        // -----------------------------
        /* DG_Comment/replace 
		for (i = 3; i > 0; i = i - 1)
            rd_pipe[i] <= rd_pipe[i-1];
        rd_pipe[0] <= 1; // DG replaced 0 w/1
		*/
		rd_pipe <= {rd_pipe[2:0],1'b1};  // DG: new version
		
        if (rd_pipe[3] && rd_count > 0) begin
            dq_out <= mem[rd_bank][active_row[rd_bank]][rd_col];
            dq_oe  <= 1;
            rd_col <= rd_col + 1;
            rd_count <= rd_count - 1;

            if (rd_count == 1 && auto_pre) begin
                if (act_timer[rd_bank] < tRAS)
                    $error("tRAS violation on auto-precharge");
                bank_open[rd_bank] <= 0;
                pre_timer[rd_bank] <= 0;
            end
          end
		end
		
        // -----------------------------
        // WRITE
        // -----------------------------
        if (cmd_wr) begin
            if (!bank_open[BA])
                $error("WRITE to closed bank");
            if (act_timer[BA] < tRCD)
                $error("tRCD violation on WRITE");

			wr_bank  <= BA;
            wr_col   <= ADDR[9:0]+1;
            wr_count <= burst_length-1;  // Since first write occurs here
			
            if (!DQM[0]) mem[BA][active_row[BA]][ADDR[9:0]][7:0]   <= DQ[7:0];
            if (!DQM[1]) mem[BA][active_row[BA]][ADDR[9:0]][15:8]  <= DQ[15:8];
            if (!DQM[2]) mem[BA][active_row[BA]][ADDR[9:0]][23:16] <= DQ[23:16];
            if (!DQM[3]) mem[BA][active_row[BA]][ADDR[9:0]][31:24] <= DQ[31:24];

            wr_timer[BA] <= 0;
          end
		else   // Write Burst (DG)
		  if (wr_count > 0) begin

			if (!DQM[0]) mem[wr_bank][active_row[wr_bank]][wr_col][7:0]   <= DQ[7:0];
            if (!DQM[1]) mem[wr_bank][active_row[wr_bank]][wr_col][15:8]  <= DQ[15:8];
            if (!DQM[2]) mem[wr_bank][active_row[wr_bank]][wr_col][23:16] <= DQ[23:16];
            if (!DQM[3]) mem[wr_bank][active_row[wr_bank]][wr_col][31:24] <= DQ[31:24];
            //dq_oe  <= 1;
            wr_col <= wr_col + 1;
            wr_count <= wr_count - 1;

            if (wr_count == 1 && auto_pre) begin
                if (act_timer[wr_bank] < tRAS)
                    $error("tRAS violation on auto-precharge");
                bank_open[wr_bank] <= 0;
                pre_timer[wr_bank] <= 0;
            end
          
		end

        // -----------------------------
        // PRECHARGE
        // -----------------------------
        if (cmd_pre) begin
            if (wr_timer[BA] < tWR)
                $error("tWR violation on precharge");
            if (act_timer[BA] < tRAS)
                $error("tRAS violation on precharge");

            bank_open[BA] <= 0;
            pre_timer[BA] <= 0;
        end
    end

    // ------------------------------------------------------------
    // Initialization
    // ------------------------------------------------------------
    initial begin
        dq_oe         = 0;
        burst_length  = 1;
        cas_latency   = 2;
        refresh_timer = 0;
        refresh_busy  = 0;
        rfc_timer     = 0;

        for (i = 0; i < BANKS; i = i + 1) begin
            bank_open[i]  = 0;
            active_row[i] = 0;
            act_timer[i]  = 100;
            pre_timer[i]  = 100;
            wr_timer[i]   = 100;
        end
    end

endmodule
