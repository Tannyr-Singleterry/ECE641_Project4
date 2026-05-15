// ============================================================================
// Copyright (c) 2025 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development
//   Kits made by Terasic.  Other use of this code, including the selling
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use
//   or functionality of this code.
//
// ============================================================================
//
//  Terasic Technologies Inc
//  No.80, Fenggong Rd., Hukou Township, Hsinchu County 303035. Taiwan
//
//
//                     web: http://www.terasic.com/
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Mon Jun  2 00:32:49 2025
// ============================================================================

// v2:  connect HDMI to SDRAM
// Apr26 - configured for:  a) 100 MHz system clk, including SDRAM;  b)  640x480 VGA

module golden_top(

      ///////// CLOCK /////////
      input              CLOCK0_50,
      input              CLOCK1_50,

      ///////// KEY /////////
      input    [ 3: 0]   KEY, //BUTTON is Low-Active

      ///////// SW /////////
      input    [ 9: 0]   SW,

      ///////// LED /////////
      output   [ 9: 0]   LEDR, //LED is Low-Active

      ///////// Seg7 /////////
      output   [ 6: 0]   HEX0,
      output   [ 6: 0]   HEX1,
      output   [ 6: 0]   HEX2,
      output   [ 6: 0]   HEX3,
      output   [ 6: 0]   HEX4,
      output   [ 6: 0]   HEX5,

      ///////// SDRAM /////////
      output             DRAM_CLK,
      output             DRAM_CKE,
      output   [12: 0]   DRAM_ADDR,
      output   [ 1: 0]   DRAM_BA,
      inout    [31: 0]   DRAM_DQ,
      output             DRAM_CS_n,
      output             DRAM_WE_n,
      output             DRAM_CAS_n,
      output             DRAM_RAS_n,
      output   [ 3: 0]   DRAM_DQM,

      ///////// HDMI /////////
      inout              HDMI_LRCLK,
      inout              HDMI_MCLK,
      inout              HDMI_SCLK,
      output             HDMI_TX_CLK,
      output             HDMI_TX_HS,
      output             HDMI_TX_VS,
      output   [23: 0]   HDMI_TX_D,
      output             HDMI_TX_DE,
      input              HDMI_TX_INT,
      inout              HDMI_I2S0,


      ///////// I2C for HDMI and ADC /////////
      inout              FPGA_I2C_SCL,
      inout              FPGA_I2C_SDA,

      ///////// UART /////////
      output             FPGA_UART_TX,
      input              FPGA_UART_RX,

      ///////// GPIO /////////
      inout    [35: 2]   GPIO_D,
	  input [1:0] GPIO_Din

);


          // lights when KEY[1] NOT pressed, off when pressed // confirms cam_capture is issuing writes    // confirms cam_capture is issuing writes

//----HEX off device
/*
assign HEX0 =7'h7f;
assign HEX1 =7'h7f;
assign HEX2 =7'h7f;
assign HEX3 =7'h7f;
assign HEX4 =7'h7f;
assign HEX5 =7'h7f;
*/

//----SDRAM off
/*
assign DRAM_DQ   =32'hzzzz_zzzzz;
assign DRAM_CS_n =1'b1;
assign DRAM_WE_n =1'b1;
assign DRAM_CAS_n=1'b1;
assign DRAM_RAS_n=1'b1;
assign DRAM_DQM  =4'b1111;
*/

//=======================================================
//  wire define
//=======================================================
wire AUD_CTRL_CLK ;
wire AUD_BCLK   ;
wire DAC_DACDAT ;
wire AUD_DACLRCK; 
wire reset_n;
wire  V_locked ,A_locked ;
wire  pll_12M288; 
wire  SYSTEM_50MHZ;
wire [7:0] vpg_r;
wire [7:0] vpg_g;
wire [7:0] vpg_b;				
wire HDMI_READY ;
wire HDMI_I2C_SCLK ; 

  wire        AUTO_FOC ;
  wire        READ_Request ;
  wire		VGA_CLK;
  wire		VGA_VS;
  wire		VGA_HS;
  wire		VGA_DE;
  wire 	[7:0]VGA_B_A, VGA_B;
  wire 	[7:0]VGA_G_A, VGA_G;
  wire 	[7:0]VGA_R_A, VGA_R;
  wire        VGA_CLK_25M ;
  wire        RESET_N  ; 
 
  wire [15:0] H_Cont ; 
  wire [15:0] V_Cont ; 
  wire        I2C_RELEASE ;  
  wire        CAMERA_I2C_SCL_MIPI ; 
  wire        CAMERA_I2C_SCL_AF ;
   wire        CAMERA_I2C_SDA_MIPI ; 
  wire        CAMERA_I2C_SDA_AF ;
 
  wire        CAMERA_MIPI_RELAESE ;
  wire        MIPI_BRIDGE_RELEASE ;
 
  wire        RESET_KEY ; 
 
	wire 		          		CAMERA_I2C_SCL;
	wire 		          		CAMERA_I2C_SDA;
	wire		          		CAMERA_PWDN_n;
	wire		          		MIPI_CS_n;
	wire 		          		MIPI_I2C_SCL;
	wire 		          		MIPI_I2C_SDA;
	wire		          		MIPI_MCLK;
	wire 		          		MIPI_PIXEL_CLK;
	wire 		     [9:0]		MIPI_PIXEL_D;
	wire 		          		MIPI_PIXEL_HS;
	wire 		          		MIPI_PIXEL_VS;
	wire		          		MIPI_REFCLK;
	wire		          		MIPI_RESET_n;
	
	
	
	wire [1:0] bank_sel;
assign bank_sel = SW[9:8];

wire record_req;
assign record_req = ~KEY[1];

wire cam_wr_addr_valid;
wire [23:0] cam_wr_addr;
wire cam_wr_data_valid;
wire [31:0] cam_wr_data;


wire uart_wr_addr_valid;
wire [23:0] uart_wr_addr;
wire uart_wr_data_valid;
wire [31:0] uart_wr_data;
wire uart_rd_addr_valid;
wire [23:0] uart_rd_addr;
wire uart_rd_data_valid;
wire [31:0] uart_rd_data;

wire [7:0] hdmi_pixel_r;
wire [7:0] hdmi_pixel_g;
wire [7:0] hdmi_pixel_b;
wire hdmi_pixel_valid;
wire image_loaded;
assign image_loaded = 1'b1;

wire sdram_busy;
wire sdram_rd_req;
wire sdram_wr_req;
wire [23:0] sdram_addr;
wire [31:0] sdram_wr_data;
wire [31:0] sdram_rd_data;
wire sdram_rd_valid;
wire sdram_wr_next;
wire vpg_pclk;

VEDIO_PLL u_VEDIO_PLL(
    .refclk   (CLOCK0_50),
    .outclk_0 (vpg_pclk),
    .locked   (V_locked),
    .rst      (~reset_n)
);



//=======================================================
//  Structural coding
//=======================================================
//--RESET 	
assign reset_n = ~ninit_done;	
//---INIT RESET 
wire ninit_done;
	ResetRelease ResetRelease_inst (
		.ninit_done (ninit_done)  
	);
	
reg [7:0] cam_reset_cnt;
reg cam_ar;

always @(posedge CLOCK0_50)
begin
    if(!ninit_done)
    begin
        cam_reset_cnt <= 8'd0;
        cam_ar        <= 1'b0;
    end
    else if(cam_reset_cnt < 8'hFF)
    begin
        cam_reset_cnt <= cam_reset_cnt + 1;
        cam_ar        <= 1'b0;
    end
    else
        cam_ar <= 1'b1;
end
	 //----LED off device
assign LEDR[9] = ~mem_busy;
assign LEDR[6] = ~cam_wr_addr_valid;  // lights when capture is writing
assign LEDR[8] = record_req;    
//-- PLL LOCK
assign LEDR[5] = ~V_locked	;
//assign LEDR[6] = ~A_locked	;

//-- HDMI SET READY	
assign LEDR[4] = ~HDMI_READY	 ;

//-----heart ----
CLOCKMEM  ckK0( .RESET_n(1), .CLK(HDMI_TX_CLK    ) ,.CLK_FREQ ( 148_500_000 )  ,.CK_1HZ  (LEDR[0] ) ) ;
CLOCKMEM  ckK1( .RESET_n(1), .CLK(AUD_DACLRCK    ) ,.CLK_FREQ (      48_000 )  ,.CK_1HZ  (LEDR[1] ) ) ;
CLOCKMEM  ckK2( .RESET_n(1), .CLK(SYSTEM_50MHZ   ) ,.CLK_FREQ (  50_000_000 )  ,.CK_1HZ  (LEDR[2] ) ) ;
CLOCKMEM  ckK3( .RESET_n(1), .CLK(AUD_CTRL_CLK   ) ,.CLK_FREQ (  12_280_000 )  ,.CK_1HZ  (LEDR[3] ) ) ;

//---AV PLL 


AUDIO_PLL u_AUDIO_PLL(
    .refclk       (CLOCK1_50     ),
    .outclk_0     (pll_12M288    ),//12.288136Mhz
    .locked       (A_locked     ),
	 .rst          (~reset_n      )
);


wire	hdmi_sel;				// if =0, then send camera out to HDMI; if=1, then SDRAM stored image to HDMI
assign hdmi_sel = SW[7];

wire	HDMI_TX_DE_sdram;
wire 	HDMI_TX_CLK_sdram;
wire	HDMI_TX_HS_sdram;
wire	HDMI_TX_VS_sdram;


assign SYSTEM_50MHZ = CLOCK0_50;//
 
assign HDMI_TX_D[23:16] = hdmi_sel ? vpg_r : VGA_R;
assign HDMI_TX_D[15:8]  = hdmi_sel ? vpg_g : VGA_G;
assign HDMI_TX_D[7:0]   = hdmi_sel ? vpg_b : VGA_B;
assign HDMI_TX_DE = hdmi_sel ? HDMI_TX_DE_sdram : (h_act & v_act);
assign HDMI_TX_HS = hdmi_sel ?  HDMI_TX_HS_sdram : VGA_HS;
assign HDMI_TX_VS = hdmi_sel ? HDMI_TX_VS_sdram : VGA_VS;
// assign HDMI_TX_CLK = hdmi_sel ? HDMI_TX_CLK_sdram : VGA_CLK;  // Referencing the VGA_CLK that originated from the MIPI_PIXEL_CLK gives routability errors in Quartus
assign HDMI_TX_CLK = HDMI_TX_CLK_sdram;


wire [23:0] pixel_data;
assign pixel_data = {hdmi_pixel_r, hdmi_pixel_g, hdmi_pixel_b};

// Gate fifo_rdreq with hdmi_pixel_valid from sdram_mgr
// vpg drives rd_data_fifo_rdreq but we override it with hdmi_pixel_valid

wire vpg_clk;

// Loopback for HDMI output using signals from Camera (VGA, H_Cont, V_cont)

wire h_act, v_act;

assign h_act = ((H_Cont > 159) && (H_Cont <= 799));  // H_Cont and V_cont from the Camera/MIPI Interface
assign v_act = ((V_Cont > 33) && (V_Cont <= 524));

//assign SYSTEM_50MHZ = CLOCK0_50;//
 
	
//--HDMI timing generater & //pattern generator
vpg	u_vpg (
	.vpg_pclk    (vpg_pclk   ),//vedio clock input
	.reset_n     (reset_n    ),    
	.vpg_de      (HDMI_TX_DE_sdram ),
	.vpg_hs      (HDMI_TX_HS_sdram ),
	.vpg_vs      (HDMI_TX_VS_sdram ),
	.vpg_pclk_out(HDMI_TX_CLK_sdram),
	.vpg_r       (vpg_r),
	.vpg_g       (vpg_g),
	.vpg_b       (vpg_b),
	.fifo_rdreq(),
	.pixel_fifo({hdmi_pixel_r, hdmi_pixel_g, hdmi_pixel_b})

	);
								
//--  HDMI I2C	SETTING
I2C_HDMI_Config u_I2C_HDMI_Config (
	              .iCLK       (SYSTEM_50MHZ  ),
	              .iRST_N     (reset_n & KEY[3]),
	              .I2C_SCLK   (FPGA_I2C_SCL  ),
	              .I2C_SDAT   (FPGA_I2C_SDA  ),
	              .HDMI_TX_INT(HDMI_TX_INT   ),
	              .READY      (HDMI_READY    ) 	
	            );
			



//---Audio Master L/RCLK , BCK ,DATA  generater 

assign AUD_CTRL_CLK =pll_12M288;

AUDIO_DAC 	u_AUDIO_DAC	(	//	Audio Side
					.oAUD_BCK       (AUD_BCLK        ),
					.oAUD_DATA      (DAC_DACDAT      ),
					.oAUD_LRCK      (AUD_DACLRCK     ),
					//	Control Signals
					.iSrc_Select    (2'b00           ),
			      .iCLK_18_4      (AUD_CTRL_CLK    ),//12.288000MHz --12.288136Mhz
					.iRST_N         (HDMI_READY      )
					);
										
// HDMI I2S out
assign HDMI_MCLK  = AUD_CTRL_CLK;
assign HDMI_SCLK  = AUD_BCLK     ;
assign HDMI_LRCLK = AUD_DACLRCK  ;	

//--key-in KEY3 ,HDMI out 1k sin-tone	
//assign HDMI_I2S0 = KEY[3]? 0 : DAC_DACDAT	;  // DG:  disable the sine tone out
assign HDMI_I2S0 = 1'b0;


//
// Start Camera Interface Structural Coding Below
//

// GPIO Inputs
assign MIPI_PIXEL_D = GPIO_D[12:3];
assign MIPI_PIXEL_CLK = GPIO_Din[1];
assign MIPI_PIXEL_HS = GPIO_D[22];
assign MIPI_PIXEL_VS = GPIO_D[20];

// GPIO Outputs
assign GPIO_D[25] = CAMERA_PWDN_n;
assign GPIO_D[23] = MIPI_CS_n;
assign GPIO_D[28] = MIPI_MCLK;
assign GPIO_D[18] = MIPI_REFCLK;
assign GPIO_D[24] = MIPI_RESET_n;

// GPIO InOuts, a guide for assigning in the CAMERA_D8M module below
//assign GPIO_D[26] = CAMERA_I2C_SCL;
//assign GPIO_D[27] = CAMERA_I2C_SDA;
//assign GPIO_D[30] = MIPI_I2C_SCL;
//assign GPIO_D[31] = MIPI_I2C_SDA;


//=======================================================
// Structural coding
//=======================================================


assign UART_RTS =0; 
assign UART_TXD =0; 
assign RESET_KEY      = KEY[3]; 
assign CAMERA_PWDN_n  = RESET_KEY; 

//----- RESET RELAY  --		
RESET_DELAY			u2	(	
							.iRST  ( RESET_KEY ),
                     .iCLK  ( CLOCK0_50 ),				
						   .oREADY( RESET_N)  
							
						);


CAMERA_D8M camera(

	  .RESET_N ( RESET_N),	// active low
	  .CLOCK0_50(CLOCK0_50),

	  /////// Auto Focus ////
	  .Focus_Area(SW[3]),    // 0-whole area, 1-middle area
	  .Start_Focus(KEY[2]),
	  
      ///////// Seg7 /////////
      .HEX0(HEX0),  // HEX[1:0] used to display video output frame rate in Hz
      .HEX1(HEX1),
 
 
	 // I2C interfaces
	  .MIPI_I2C_SCL(GPIO_D[30]), 
	  .MIPI_I2C_SDA(GPIO_D[31]), 
	  .CAMERA_I2C_SCL(GPIO_D[26]),
	  .CAMERA_I2C_SDA(GPIO_D[27]),
	  
	  // MIPI Bridge
	  .MIPI_PIXEL_D(MIPI_PIXEL_D),
	  .MIPI_PIXEL_CLK(MIPI_PIXEL_CLK),
	  .MIPI_PIXEL_HS(MIPI_PIXEL_HS),
	  .MIPI_PIXEL_VS(MIPI_PIXEL_VS),
	  .MIPI_MCLK(MIPI_MCLK),
	  .MIPI_REFCLK(MIPI_REFCLK),
	  .MIPI_RESET_n(MIPI_RESET_n),
	  .MIPI_CS_n(MIPI_CS_n),

  
      ///////// Output Video /////////
      .VGA_CLK(VGA_CLK),
      .VGA_HS(VGA_HS),
      .VGA_VS(VGA_VS),
      .VGA_R(VGA_R),
      .VGA_G(VGA_G),
      .VGA_B(VGA_B),
      .VGA_DE(VGA_DE),
	  .H_Cont (H_Cont),
	  .V_Cont (V_Cont)
 

);
 





// SDRAM and UART code below

//--UART tx loopback to rx 
assign   FPGA_UART_TX =  FPGA_UART_RX & tx_out; 



    wire   ar_clkdiv, din, data_clk, tx_clk, tx_start, ar, new_rx, tx_out;
	 wire [7:0] dout, tx_word;
	 wire tx_done;
	 
	 // Signal declarations for SDRAM controller interface to UART Mgr
	wire mem_wr_req;
	wire mem_rd_req;
	wire [23:0] mem_addr;
	wire [31:0] mem_wr_data;
	wire [31:0]	mem_rd_data;
	wire	mem_rd_valid;
	wire 	mem_busy;
	wire	mem_wr_next;
	 
	 wire [31:0] control_regs [3:0];  // 32-bit Control Registers [3:0]

	wire 	wr_data_fifo_wrreq;
	wire	wr_data_fifo_full;
	wire  [31:0]	wr_data_fifo_datain;

	wire	rd_data_fifo_rdreq;
	wire	rd_data_fifo_full;
	wire	rd_data_fifo_empty;
	wire  [31:0]	rd_data_fifo_dataout;

	wire	wr_addr_fifo_wrreq;
	wire	wr_addr_fifo_full;
	wire [23:0]	wr_addr_fifo_datain;

	wire	rd_addr_fifo_wrreq;
	wire	rd_addr_fifo_full;
	wire [23:0]	rd_addr_fifo_datain;
	
	wire [1:0] reg_idx;
	
	
	wire sdram_ctrl_clk;  // PLL Output 

	assign reg_idx = SW[1:0];	// Use lower 2 dip switches to choose which control reg to display
	
	
    assign ar = KEY[3];
	assign clk = sdram_ctrl_clk;
    assign din = FPGA_UART_RX;

 /* // dividers for 50 MHz input clock
    clk_div #(8, 217) rx_div (.ar(ar_clkdiv), .clk_in(clk), .clk_out(data_clk));
    clk_div #(8, 217) tx_div (.ar(ar), .clk_in(clk), .clk_out(tx_clk));
*/
	// dividers for 100 MHz input clock
    clk_div #(9, 434) rx_div (.ar(ar_clkdiv), .clk_in(clk), .clk_out(data_clk));
    clk_div #(9, 434) tx_div (.ar(ar), .clk_in(clk), .clk_out(tx_clk));

/*
	// dividers for 148.5 MHz input clock
    clk_div #(10, 645) rx_div (.ar(ar_clkdiv), .clk_in(clk), .clk_out(data_clk));
    clk_div #(10, 645) tx_div (.ar(ar), .clk_in(clk), .clk_out(tx_clk));
*/

    rs232_rx rcvr(.ar(ar), .clk(data_clk), .clk_fast(clk), 
       .din(din), .show_prev(1'b0), .dout(dout), 
		.ar_clkdiv(ar_clkdiv), .new_rx(new_rx));

	rs232_tx transmitter(.ar(ar), .clk(tx_clk), .tx_start(tx_start), .tx_done(tx_done), 
		.tx_word(tx_word), .tx_out(tx_out) );

	// Second version of uart_mgr to work with sdram_mgr
	uart_mgr uart_manager(.ar(ar), .clk(clk), .new_rx(new_rx), .tx_done(tx_done), 
		.tx_start(tx_start), .rx_word(dout), .tx_word(tx_word), .control_regs(control_regs),
		.wr_data_fifo_wrreq(wr_data_fifo_wrreq), .wr_data_fifo_full(wr_data_fifo_full),
		.wr_data_fifo_datain(wr_data_fifo_datain), 
		//.rd_data_fifo_rdreq(rd_data_fifo_rdreq),  // HDMI version 
		.rd_data_fifo_full(rd_data_fifo_full), .rd_data_fifo_empty(rd_data_fifo_empty), .rd_data_fifo_dataout(rd_data_fifo_dataout),
		.wr_addr_fifo_wrreq(wr_addr_fifo_wrreq), .wr_addr_fifo_full(wr_addr_fifo_full),
		.wr_addr_fifo_datain(wr_addr_fifo_datain), .rd_addr_fifo_wrreq(rd_addr_fifo_wrreq),
		.rd_addr_fifo_full(rd_addr_fifo_full), .rd_addr_fifo_datain(rd_addr_fifo_datain));


//	sevseg_dec dec0(.x_in(control_regs[reg_idx][3:0]), .segs(HEX0));
//	sevseg_dec dec1(.x_in(control_regs[reg_idx][7:4]), .segs(HEX1));
	sevseg_dec dec2(.x_in(control_regs[reg_idx][11:8]), .segs(HEX2));
	sevseg_dec dec3(.x_in(control_regs[reg_idx][15:12]), .segs(HEX3));
	sevseg_dec dec4(.x_in(control_regs[reg_idx][19:16]), .segs(HEX4));
	sevseg_dec dec5(.x_in(control_regs[reg_idx][23:20]), .segs(HEX5));
	
sdram_controller_32bit sdram_ctrl (
    .clk          (sdram_ctrl_clk),
    .rst_n        (ar),
    .start_refresh(~HDMI_TX_HS),
    .num_words    (10'd512),
    .wr_req       (mem_wr_req),
    .rd_req       (mem_rd_req),
    .addr         (mem_addr),
    .wr_data      (mem_wr_data),
    .rd_data      (mem_rd_data),
    .rd_valid     (mem_rd_valid),
    .busy         (mem_busy),
    .wr_next      (mem_wr_next),
    .sdram_a      (DRAM_ADDR),
    .sdram_ba     (DRAM_BA),
    .sdram_dq     (DRAM_DQ),
    .sdram_dqm    (DRAM_DQM),
    .sdram_cke    (DRAM_CKE),
    .sdram_cs_n   (DRAM_CS_n),
    .sdram_ras_n  (DRAM_RAS_n),
    .sdram_cas_n  (DRAM_CAS_n),
    .sdram_we_n   (DRAM_WE_n)
);


cam_capture cam_capture_inst (
    .ar              (cam_ar),
    .clk             (CLOCK0_50),
    .record_req      (record_req),
    .bank_sel        (bank_sel),
    .VGA_CLK         (VGA_CLK),
    .VGA_HS          (VGA_HS),
    .VGA_VS          (VGA_VS),
    .VGA_DE          (VGA_DE),
    .VGA_R           (VGA_R),
    .VGA_G           (VGA_G),
    .VGA_B           (VGA_B),
    .cam_wr_addr_valid(cam_wr_addr_valid),
    .cam_wr_addr      (cam_wr_addr),
    .cam_wr_data_valid(cam_wr_data_valid),
    .cam_wr_data      (cam_wr_data)
);

sdram_mgr sdram_mgr_inst (
    .ar                  (ar),
    .clk                 (sdram_ctrl_clk),
    .clk_hdmi            (sdram_ctrl_clk),
    // UART write interface
    .wr_data_fifo_wrreq  (wr_data_fifo_wrreq),
    .wr_data_fifo_full   (wr_data_fifo_full),
    .wr_data_fifo_datain (wr_data_fifo_datain),
    .rd_data_fifo_rdreq  (rd_data_fifo_rdreq),
    .rd_data_fifo_full   (rd_data_fifo_full),
    .rd_data_fifo_empty  (rd_data_fifo_empty),
    .rd_data_fifo_dataout(rd_data_fifo_dataout),
    .wr_addr_fifo_wrreq  (wr_addr_fifo_wrreq),
    .wr_addr_fifo_full   (wr_addr_fifo_full),
    .wr_addr_fifo_datain (wr_addr_fifo_datain),
    .rd_addr_fifo_full   (rd_addr_fifo_full),
    .rd_addr_fifo_datain (rd_addr_fifo_datain),
    .vsynch              (HDMI_TX_VS_sdram),
    // PR4: Camera write interface
    .cam_wr_addr_valid   (cam_wr_addr_valid),
    .cam_wr_addr         (cam_wr_addr),
    .cam_wr_data_valid   (cam_wr_data_valid),
    .cam_wr_data         (cam_wr_data),
    // PR4: Bank select
    .bank_sel            (bank_sel),
    // SDRAM controller interface
    .mem_wr_req          (mem_wr_req),
    .mem_rd_req          (mem_rd_req),
    .mem_addr            (mem_addr),
    .mem_wr_data         (mem_wr_data),
    .mem_rd_data         (mem_rd_data),
    .mem_rd_valid        (mem_rd_valid),
    .mem_busy            (mem_busy),
    .mem_wr_next         (mem_wr_next)
);
	
sdram_pll pll_sdram(
		.refclk(CLOCK0_50),   //  refclk.clk,    The reference clock source that drives the I/O PLL.
		.locked(LEDR[7]),   //  locked.export, The IOPLL IP core drives this port high when the PLL acquires lock. The port remains high as long as the I/O PLL is locked. The I/O PLL asserts the locked port when the phases and frequencies of the reference clock and feedback clock are the same or within the lock circuit tolerance. When the difference between the two clock signals exceeds the lock circuit tolerance, the I/O PLL loses lock.
		.rst(1'b0),      //   reset.reset,  The asynchronous reset port for the output clocks. Drive this port high to reset all output clocks to the value of 0.
		.outclk_0(sdram_ctrl_clk), // outclk0.clk,    Output clock Channel 0 from I/O PLL.
		.outclk_1(DRAM_CLK)  // outclk1.clk,    Output clock Channel 1 from I/O PLL.
	);
	


endmodule
