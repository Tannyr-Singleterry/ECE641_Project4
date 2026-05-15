// UART manager, v3 to increase SDRAM memory reads and writes to 512 words

module uart_mgr(	 
	input	ar,
	input	clk,
	
	// Signals to UART transceiver
	input  	new_rx,
	output reg tx_start,
	input	tx_done,
	input [7:0]  rx_word,
	output reg [7:0] tx_word,
	
	// 2D array control regs to top level
	output reg [31:0] control_regs [3:0],  // 32-bit Control Registers [3:0]

	// Signals from/to SDRAM manager (FIFOs)
	output reg			wr_data_fifo_wrreq,
	input			wr_data_fifo_full,
	output reg  [31:0]	wr_data_fifo_datain,

	output reg			rd_data_fifo_rdreq,
	input			rd_data_fifo_full,
	input			rd_data_fifo_empty,
	input  [31:0]	rd_data_fifo_dataout,

	output reg			wr_addr_fifo_wrreq,
	input			wr_addr_fifo_full,
	output reg [23:0]	wr_addr_fifo_datain,

	output reg			rd_addr_fifo_wrreq,
	input			rd_addr_fifo_full,
	output reg [23:0]	rd_addr_fifo_datain);
	
	
	parameter BL = 512;	// Burst length for SDRAM reads and writes
	parameter CAS = 3;	// Read latency of SDRAM
	
	// Mapping of ASCII 8-bit words to data values, and commands
	reg [3:0] 	data_value;
	wire		R, W, A, C;

		
	assign R = (rx_word == 8'h52 || rx_word == 8'h72) ? 1'b1 : 1'b0;  // r=x72, R=x52
	assign W = (rx_word == 8'h57 || rx_word == 8'h77) ? 1'b1 : 1'b0;
	assign A = (rx_word == 8'h41 || rx_word == 8'h61) ? 1'b1 : 1'b0;
	assign C = (rx_word == 8'h43 || rx_word == 8'h63) ? 1'b1 : 1'b0;
	
	always @(rx_word)
		case(rx_word)  // based on ASCII
			8'h30: data_value = 4'h0;
			8'h31: data_value = 4'h1;
			8'h32: data_value = 4'h2;
			8'h33: data_value = 4'h3;
			8'h34: data_value = 4'h4;
			8'h35: data_value = 4'h5;
			8'h36: data_value = 4'h6;
			8'h37: data_value = 4'h7;
			8'h38: data_value = 4'h8;
			8'h39: data_value = 4'h9;
			8'h41: data_value = 4'ha;
			8'h61: data_value = 4'ha;
			8'h42: data_value = 4'hb;
			8'h62: data_value = 4'hb;
			8'h43: data_value = 4'hc;
			8'h63: data_value = 4'hc;
			8'h44: data_value = 4'hd;
			8'h64: data_value = 4'hd;
			8'h45: data_value = 4'he;
			8'h65: data_value = 4'he;
			8'h46: data_value = 4'hf;
			8'h66: data_value = 4'hf;
			default: data_value = 4'h0;
		endcase
		
	reg [3:0] asc_value;
	
	always @(tx_reg)
		case(tx_reg[31:28])  // based on ASCII
			4'ha: asc_value = 4'h1;
			4'hb: asc_value = 4'h2;
			4'hc: asc_value = 4'h3;
			4'hd: asc_value = 4'h4;
			4'he: asc_value = 4'h5;
			4'hf: asc_value = 4'h6;
			default: asc_value = tx_reg[31:28];
		endcase	
	
	reg	rxnew_prev, txdone_prev;
	wire rxnew_posedge, txdone_posedge;


	always @(negedge ar or posedge clk) // D FF for y
		if(~ar)
			begin
			rxnew_prev = 1'b0;
			txdone_prev = 1'b0;
			end
		else	
			begin
			rxnew_prev = new_rx;
			txdone_prev = tx_done;
			end
	
	assign rxnew_posedge = new_rx & ~rxnew_prev;  // =1 on postive edge of new_rx
	assign txdone_posedge = tx_done & ~txdone_prev;
	
		
	parameter [4:0]	Idle = 5'd0, 
					Command_Type = 5'd1,
					Read_Mem = 5'd2,
					Write_Mem = 5'd3,
					Address_Mem = 5'd4,
					Control_Reg = 5'd5,
					Wait_Mem = 5'd6,
					Tx_MemByte = 5'd7,
					Wait_TxMem = 5'd8,
				//	Mem_IncrAddr = 5'd9,
					Start_WriteDataMem = 5'd10,
					Continue_WriteMem = 5'd11,
					Get_MemAddr = 5'd12,
					Reg_Num = 5'd13,
					CR_RorW = 5'd14,
					Tx_CR_Byte = 5'd15,
					Wait_Tx_CR = 5'd16,
					Rx_CR_Byte = 5'd17,
					End_WriteMem = 5'd18,
					Address_Write = 5'd19,
					Get_MemWord = 5'd20,
					Get_MemWord_Wait = 5'd21;
					
	reg [4:0]   cs;
	
	reg [3:0] ctr;
	wire [3:0] mem_word_ctr;  // ctr - CAS (not using?)
	reg [9:0] word_ctr;  // 
	reg [1:0]	reg_idx;  // Indicates which of the four 32-bit control registers
	reg [31:0]  tx_reg;   // Control reg to be read (written to PC)
	reg [23:0]	mem_addr;   // Address to go to appropriate rd/wr FIFOs
	reg [31:0] mem_wr_data;
	
	assign wr_addr_fifo_datain = mem_addr;
	assign rd_addr_fifo_datain = mem_addr;
	//assign wr_data_fifo_datain = mem_wr_data;
	
	
	assign mem_word_ctr = ctr - CAS;  // Not using?
	
	wire [31:0] wr_data_fifo_datain_nxt;
	assign wr_data_fifo_datain_nxt = {wr_data_fifo_datain[27:0],data_value};
	
	reg read_write_n;
	
	
	always @(negedge ar or posedge clk )
	if(~ar)
	   begin
		cs = Idle;
		tx_word = 8'd0;
		tx_start = 1'b0;
		ctr = 4'd0;
		word_ctr = 10'd0;
		reg_idx = 2'b00;
		read_write_n = 1'b0;  
		mem_addr = 24'd0;
		mem_wr_data = 32'd0;
		rd_data_fifo_rdreq = 1'd0;
		
	   end
	else
	   case(cs)
			Idle:
				 if(rxnew_posedge)
				   begin
					cs = Command_Type;
				   end
				 else
				   begin
					cs = Idle;
					ctr = 4'd0;
					word_ctr = 10'd0;
					read_write_n = 1'b0;
					rd_data_fifo_rdreq = 1'd0;
				   end
				
			Command_Type:
				begin
				  cs = Idle;  // Default = Idle, go back if no valid cmd received
				  
				  if(R) 
					begin
					cs = Address_Mem;
					read_write_n = 1'b1;
					end
				  if(W) 
					begin
					cs = Address_Mem;
					read_write_n = 1'b0;
					end
					
				  // if(A) cs = Address_Mem;
				  if(C) cs = Control_Reg;
				end
			
			Read_Mem:
					begin
					rd_addr_fifo_wrreq = 1'b0; // Finish rd_addr write
					
					word_ctr = 0;
					cs = Wait_Mem;
					end
				
			Wait_Mem:
				begin
							
				
				if(~rd_data_fifo_empty)
					begin
					rd_data_fifo_rdreq = 1'b1;   // need to wait one clock cycle to get data?
					// tx_reg = rd_data_fifo_dataout;  // Continue reading same data for burst
					word_ctr = word_ctr + 1;
					cs = Get_MemWord_Wait;
					end
				/*
				if(ctr >= BL)  // Remove -1 ?
					begin	
					ctr = 0;
					cs = Tx_MemByte;
					end */
				end
				
			Get_MemWord_Wait:
				begin
							
					rd_data_fifo_rdreq = 1'b0;   
					//tx_reg = rd_data_fifo_dataout;  // Continue reading same data for burst
					
					ctr = 0;
					cs = Get_MemWord;
					
				end

			Get_MemWord:
				begin
							
					//rd_data_fifo_rdreq = 1'b0;   
					tx_reg = rd_data_fifo_dataout;  // Continue reading same data for burst
					
					ctr = 0;
					cs = Tx_MemByte;
					
				end

				
			Tx_MemByte:  
				begin
					cs = Wait_TxMem;
					tx_start = 1'b1;
					
					if(tx_reg[31:28] > 9)
						tx_word = {4'h4, asc_value};  // Convert a-f back to ASCII 
					else
						tx_word = {4'h3, tx_reg[31:28]};
					
					tx_reg = {tx_reg[27:0], 4'h0};
					
					ctr = ctr + 1;
				end
				

			Wait_TxMem:
				if(txdone_posedge)
					begin
					if(ctr < 8)
						cs = Tx_MemByte;
					else
						begin
						tx_start = 1'b0;
						
						if(word_ctr >= BL)  // BL instead of 8 for v3
							cs = Idle;
						else
							cs = Wait_Mem;
						end
					end
				
			 /*
			Mem_IncrAddr:
				begin
				//mem_addr = mem_addr + BL; 
				cs = Idle;
				end
			*/
			
			Write_Mem:
				begin
				wr_addr_fifo_wrreq = 1'b0;
				wr_data_fifo_wrreq = 1'b0;
				
				if(rxnew_posedge)
					begin
					// mem_wr_data = {mem_wr_data[27:0],data_value}; 
					wr_data_fifo_datain = wr_data_fifo_datain_nxt; 
					ctr = ctr + 1;
					
					if(ctr >= 8)
						begin
						word_ctr = word_ctr + 1;
						cs = Start_WriteDataMem;
						end
					end
				end
				
			
			Start_WriteDataMem:
					begin
					wr_data_fifo_wrreq = 1'b1;
					ctr = 0;
					
					if(word_ctr < BL)  // Change 8 to BL for v3
						cs = Write_Mem;
					else
						cs = End_WriteMem;
						
					end
				
			End_WriteMem:
					begin
					wr_data_fifo_wrreq = 1'b0;
					cs = Idle;
					end
				
			
			Address_Mem:
				if(rxnew_posedge)
					begin
					
					mem_addr = {mem_addr[19:0],data_value}; 
					ctr = ctr + 1;
					
					if(ctr >= 6)
						begin
						cs = Address_Write;
						ctr = 0;
						end
			
					end

			Address_Write:
				
					if(read_write_n)
						begin
						rd_addr_fifo_wrreq = 1'b1;
						cs = Read_Mem;
						end
					else
						begin
						wr_addr_fifo_wrreq = 1'b1;
						cs = Write_Mem;
						end
	

			Control_Reg:
				if(rxnew_posedge)
					begin
						cs = Reg_Num;
						reg_idx = data_value[1:0];  // only lower 2 bits for values of 0-3
					end
			
			Reg_Num:
				begin
				cs = CR_RorW;
				ctr = 4'd0;
				end
				
				
			CR_RorW:
				if(rxnew_posedge)
					if(R)
						begin
						cs = Tx_CR_Byte;
						tx_reg = control_regs[reg_idx];
						end
					else if(W)
						cs = Rx_CR_Byte;
			
			Tx_CR_Byte:
					begin
					cs = Wait_Tx_CR;
					tx_start = 1'b1;
					
					if(tx_reg[31:28] > 9)
						tx_word = {4'h4, tx_reg[31:28]};
					else
						tx_word = {4'h3, tx_reg[31:28]};
					
					tx_reg = {tx_reg[27:0], 4'h0};
					
					ctr = ctr + 1;
					end
					
			Wait_Tx_CR:
				if(txdone_posedge)
					begin
					if(ctr < 8)
						cs = Tx_CR_Byte;
					else
						begin
						tx_start = 1'b0;
						cs = Idle;
						end
					end
					
			Rx_CR_Byte:
				if(rxnew_posedge)
					begin
					
					control_regs[reg_idx] = {control_regs[reg_idx][27:0],data_value}; 
					ctr = ctr + 1;
					
					if(ctr >= 8)
						cs = Idle;

					end
					
			default:
				cs = Idle;
			
		endcase
         
            
	
	endmodule
	