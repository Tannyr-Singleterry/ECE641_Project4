`timescale 1ns / 1ps

module tb_sdram_controller;

    // Parameters matching the controller
    localparam real CLK_PERIOD    = 10.0;     // 100 MHz, 10 ns period
    localparam integer CAS_LATENCY = 3;
    localparam integer BURST_LENGTH = 8;
    
    // Clock and reset
    reg         clk;
    reg         rst_n;
    
    // User side interface
    reg         wr_req;
    reg         rd_req;
    reg  [23:0] addr;
    reg  [31:0] wr_data;
    wire [31:0] rd_data;
    wire        rd_data_valid;
    wire        busy;
    
    // SDRAM interface
    wire [12:0] sdram_a;
    wire [1:0]  sdram_ba;
    wire [31:0] sdram_dq;
    wire        sdram_dqm0, sdram_dqm1;
    wire        sdram_cke;
    wire        sdram_cs_n;
    wire        sdram_ras_n;
    wire        sdram_cas_n;
    wire        sdram_we_n;
    
    // Bidirectional data emulation
    reg  [31:0] sdram_dq_drive;
    reg         sdram_dq_oe;           // 1 = drive from testbench (read data)
    assign #4 sdram_dq = sdram_dq_oe ? sdram_dq_drive : 32'hZZZZ_ZZZZ;
    
    // Instantiate the controller (use your actual module name)
    sdram_controller_32bit
    #(
        .CLK_PERIOD       (CLK_PERIOD),
        .CAS_LATENCY      (CAS_LATENCY),
        .BURST_LENGTH     (BURST_LENGTH)
        //.REFRESH_PERIOD (7812)     // ns
        // Add your other timing parameters here if needed:
        // .tRP(20), .tRC(60), .tRCD(20), .tRAS(42), .tWR(12), etc.
    )
    u_controller (
        .clk             (clk),
        .rst_n           (rst_n),
        .wr_req          (wr_req),
        .rd_req          (rd_req),
        .addr            (addr),
        .wr_data         (wr_data),
        .rd_data         (rd_data),
        .rd_valid   (rd_data_valid),
        .busy            (busy),
        
        .sdram_a         (sdram_a),
        .sdram_ba        (sdram_ba),
        .sdram_dq        (sdram_dq),
        .sdram_dqm      ({sdram_dqm1, sdram_dq0}),
        //.sdram_dqm1      (sdram_dqm1),
        .sdram_cke       (sdram_cke),
        .sdram_cs_n      (sdram_cs_n),
        .sdram_ras_n     (sdram_ras_n),
        .sdram_cas_n     (sdram_cas_n),
        .sdram_we_n      (sdram_we_n)
    );
    
    // Clock generator
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Dump waveform
    initial begin
        $dumpfile("sdram_controller_tb.vcd");
        $dumpvars(0, tb_sdram_controller);
    end
    
    // Test sequence
    initial begin
        // Initialize
        rst_n           = 0;
        wr_req          = 0;
        rd_req          = 0;
        addr            = 0;
        wr_data         = 32'hA5A5_A5A5;
        sdram_dq_oe     = 0;
        sdram_dq_drive  = 32'h0000_0000;
        
        #100;
        rst_n = 1;
        #200;
        
        $display("=== Waiting for initialization to complete ===");
        wait(u_controller.state == 5'd9); // IDLE state (adjust number if different)
        #300;
        
        $display("\n=== Test 1: Write burst 8 @ address 0x000000 ===");
        single_write_burst(24'h00_0000, 32'hDEAD_BEEF);
        
        #400;
        
        $display("\n=== Test 2: Read burst 8 @ same address ===");
        single_read_burst(24'h00_0000);
        
        #1000;
        
        $display("\n=== Test 3: Write different address (bank 1) ===");
        single_write_burst(24'h40_0123, 32'h1234_5678);
        
        #800;
        
        $display("\n=== Test 4: Read back from bank 1 ===");
        single_read_burst(24'h40_0123);

        #1000;
        
        $display("\n=== Test 5: Write different address (bank 2) ===");
        single_write_burst(24'h80_0123, 32'h8765_4321);
        
        #800;
        
        $display("\n=== Test 6: Read back from bank 2 ===");
        single_read_burst(24'h80_0123);

        #1000;
        
        $display("\n=== Test 7: Write different address (bank 3) ===");
        single_write_burst(24'hc0_0123, 32'h0123_4567);
        
        #800;
        
        $display("\n=== Test 8: Read back from bank 3 ===");
        single_read_burst(24'hc0_0123);


        
        #64000000;
        
        $display("\n=== Simulation finished ===");
        $stop;
    end
    
    // Task: Single write burst of 8 words
    task single_write_burst;
        input [23:0] target_addr;
        input [31:0] start_pattern;
        integer i;
        begin
            @(posedge clk);
            while (busy) @(posedge clk);
            
            addr    = target_addr;
            wr_req  = 1;
            @(posedge clk);
            wr_req  = 0;
            
            // Send 8 words
            for (i = 0; i < 8; i = i + 1) begin
                while (busy) @(posedge clk);  // wait if controller not ready
                wr_data = start_pattern ^ (32'h0000_0100 * i);  // simple pattern
                @(posedge clk);
            end
            
            $display("  Write burst started @ %t  addr=%h", $time, target_addr);
        end
    endtask
    
    // Task: Single read burst of 8 words
    task single_read_burst;
        input [23:0] target_addr;
        integer i;
        begin
            @(posedge clk);
            while (busy) @(posedge clk);
            
            addr    = target_addr;
            rd_req  = 1;
            @(posedge clk);
            rd_req  = 0;
            
            $display("  Read burst started @ %t  addr=%h", $time, target_addr);
            
            // Wait and collect read data
            for (i = 0; i < 20; i = i + 1) begin   // safety timeout
                @(posedge clk);
                if (rd_data_valid) begin
                    $display("  Read data %2d : %h   @ %t", i, rd_data, $time);
                end
            end
        end
    endtask
 
/* 
    // Emulate SDRAM read data (very simplified!)
    always @(posedge clk) begin
        if (!sdram_cs_n && !sdram_ras_n && !sdram_cas_n && sdram_we_n) begin   // READ command
            # (CAS_LATENCY * CLK_PERIOD - 1);   // approximate CAS latency delay
            sdram_dq_oe    <= 1;
            sdram_dq_drive <= 32'h5A5A_5A5A ^ {sdram_a[7:0], sdram_ba, 16'hFACE}; // fake data
            # (BURST_LENGTH * CLK_PERIOD);
            sdram_dq_oe    <= 0;
        end
    end
*/

// Instantiate the SDRAM model (instead of the simple emulation)
 /*   sdram_model u_sdram (
        .clk            (clk),
        .cke            (sdram_cke),
        .cs_n           (sdram_cs_n),
        .ras_n          (sdram_ras_n),
        .cas_n          (sdram_cas_n),
        .we_n           (sdram_we_n),
        .ba             (sdram_ba),
        .addr           (sdram_a),
        .dq             (sdram_dq),
        .dqm0           (sdram_dqm0),
        .dqm1           (sdram_dqm1)
    );
*/
	
	sdram_model samsung(
             .CLK(~clk),
             .CKE(sdram_cke),
             .CS_N(sdram_cs_n),
             .RAS_N(sdram_ras_n),
             .CAS_N(sdram_cas_n),
             .WE_N(sdram_we_n),
			.BA(sdram_ba),
			.ADDR(sdram_a),
			.DQ(sdram_dq),
			.DQM(4'h0)  // DQM is active low
);
endmodule