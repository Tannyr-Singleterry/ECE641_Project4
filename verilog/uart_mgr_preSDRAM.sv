module uart_mgr(ar, clk, new_rx, tx_done, tx_start, rx_word, tx_word, control_regs);
	input	ar;
	input	clk;
	input  	new_rx;
	output reg tx_start;
	input	tx_done;
	input [7:0]  rx_word;
	output reg [7:0] tx_word;
	output reg [31:0] control_regs [3:0];  // 32-bit Control Registers [3:0]
	
	
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
					Mem_IncrAddr = 5'd9,
					Get_WriteDataMem = 5'd10,
					WriteMem_Cmd = 5'd11,
					Get_MemAddr = 5'd12,
					Reg_Num = 5'd13,
					CR_RorW = 5'd14,
					Tx_CR_Byte = 5'd15,
					Wait_Tx_CR = 5'd16,
					Rx_CR_Byte = 5'd17;
					
	reg [4:0]   cs;
	
	reg [3:0] ctr;
	reg [1:0]	reg_idx;  // Indicates which of the four 32-bit control registers
	reg [31:0]  tx_reg;   // Control reg to be read (written to PC)
	
	always @(negedge ar or posedge clk )
	if(~ar)
	   begin
		cs = Idle;
		tx_word = 8'd0;
		tx_start = 1'b0;
		ctr = 4'd0;
		reg_idx = 2'b00;
		
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
					
				   end
				
			Command_Type:
				begin
				  if(R) cs = Read_Mem;
				  if(W) cs = Write_Mem;
				  if(A) cs = Address_Mem;
				  if(C) cs = Control_Reg;
				end
			
			Read_Mem:
				cs = Wait_Mem;

			Wait_Mem:
				cs = Tx_MemByte;
 
			Tx_MemByte:
				cs = Wait_TxMem;

			Wait_TxMem:
				cs = Mem_IncrAddr;
			 
			Mem_IncrAddr:
				cs = Idle;
			 
			Write_Mem:
				cs = Get_WriteDataMem;
			
			Get_WriteDataMem:
				cs = WriteMem_Cmd;
				
			WriteMem_Cmd:
				cs = Mem_IncrAddr;
				
			
			Address_Mem:
				cs = Get_MemAddr;

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
	