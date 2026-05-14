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
      inout    [35: 0]   GPIO_D

);


//=======================================================
//  Structural coding
//=======================================================
//---HEX OFF
//assign HEX0 =7'h7f; 
//assign HEX1 =7'h7f; 
assign HEX2 =7'h7f; 
assign HEX3 =7'h7f; 
assign HEX4 =7'h7f; 
assign HEX5 =7'h7f; 

//----LED OFF
assign   LEDR [9: 2] =8'hFF ; 


//--SDRAM no use
assign DRAM_CS_n =1'b1;//
assign DRAM_WE_n =1'b1;//
assign DRAM_CAS_n=1'b1;//
assign DRAM_RAS_n=1'b1;//
assign DRAM_DQM  =4'hf ; 
assign DRAM_DQ   =32'hzzzz_zzzz;

//--UART tx loopback to rx 
assign   FPGA_UART_TX = KEY[0]? FPGA_UART_RX :0 ; 

//--led display
assign   LEDR[1:0]= {~KEY[0], ~FPGA_UART_TX };

// Revised by DG below


    wire   ar_clkdiv, din, data_clk, ar, new_rx;
	 wire [7:0] dout;
	 
    assign ar = KEY[0];
	 assign clk = CLOCK0_50;
    assign din = FPGA_UART_RX;

    clk_div #(8, 217) divider (.ar(ar_clkdiv), .clk_in(clk), .clk_out(data_clk));
    
    serial_fsm rcvr(.ar(ar), .clk(data_clk), .clk_fast(clk), 
       .din(din), .show_prev(1'b0), .dout(dout), 
		.ar_clkdiv(ar_clkdiv), .new_rx(new_rx));

		sevseg_dec dec0(.x_in(dout[7:4]), .segs(HEX1));
		sevseg_dec dec1(.x_in(dout[3:0]), .segs(HEX0));
		
endmodule
