// D. Gruenbacher
//  April 26, 2026:  Read_FSM for getting pixels updated for potential synchronization/error conditions
//
// ECE641 Project 4 - Camera write support added
//   - cam_wr_addr_valid / cam_wr_addr : camera burst start address
//   - cam_wr_data_valid / cam_wr_data : camera pixel data
//   - bank_sel [1:0] : upper 2 bits of SDRAM address (SW[9:8])
//   Camera writes share the wr_addr and wr_data FIFOs with UART writes.
//   UART write has priority in the mux; camera takes over when UART is idle.

module sdram_mgr(
 	
	input	ar,
	input	clk,
	input	clk_hdmi,
	
	// Signals to UART manager
	input			wr_data_fifo_wrreq,
	output			wr_data_fifo_full,
	input [31:0]	wr_data_fifo_datain,

	input			rd_data_fifo_rdreq,
	output			rd_data_fifo_full,
	output 			rd_data_fifo_empty,
	output  [31:0]	rd_data_fifo_dataout,

	input			wr_addr_fifo_wrreq,
	output			wr_addr_fifo_full,
	input [23:0]	wr_addr_fifo_datain,

	//input			rd_addr_fifo_wrreq, // only for pre-HDMI 
	output			rd_addr_fifo_full,
	input [23:0]	rd_addr_fifo_datain,
	
	// input from HDMI
	input			vsynch,

	// PR4: Camera write interface
	input			cam_wr_addr_valid,
	input  [23:0]	cam_wr_addr,
	input			cam_wr_data_valid,
	input  [31:0]	cam_wr_data,

	// PR4: Bank select (SW[9:8])
	input  [1:0]	bank_sel,

	// Signals to SDRAM controller
	output reg mem_wr_req,
	output reg mem_rd_req,
	output  [23:0] mem_addr,
	output  [31:0] mem_wr_data,
	input [31:0]	mem_rd_data,
	input	mem_rd_valid,
	input 	mem_busy,
	input	mem_wr_next);
	


	// Write_Data_FIFO Declarations
	
	reg 			wr_data_fifo_rdreq;
	wire [31:0]		wr_data_fifo_dataout;
	wire [10:0]		wr_data_fifo_rdusedw;
	wire [10:0]		wr_data_fifo_wrusedw;
	wire			wr_data_fifo_empty;
	wire			wr_data_fifo_almost_full;
	wire			wr_data_fifo_almost_empty;

	// Read_Data_FIFO Declarations
	
	reg 			rd_data_fifo_wrreq;
	wire [31:0]		rd_data_fifo_datain;
	wire [10:0]		rd_data_fifo_rdusedw;
	wire [10:0]		rd_data_fifo_wrusedw;
	wire			rd_data_fifo_almost_full;
	wire			rd_data_fifo_almost_empty;
	
	// Write_Addr_FIFO Declarations
	reg 			wr_addr_fifo_rdreq;
	wire [23:0]		wr_addr_fifo_dataout;
	wire			wr_addr_fifo_empty;
	wire 			wr_data_fifo_rdrequest;
	wire [2:0]		wr_addr_fifo_usedw;
	
	// Read_Addr_FIFO Declarations
	reg 			rd_addr_fifo_rdreq;
	wire [23:0]		rd_addr_fifo_dataout;
	wire			rd_addr_fifo_empty;
	wire [2:0]		rd_addr_fifo_usedw;

	/* PR4: Camera write arbitration
	// Mux camera and UART writes into the shared wr_addr and wr_data FIFOs.
	// UART has priority; camera only pushes when UART is not writing.
	// Apply bank_sel to upper 2 bits of all write addresses.
	*/

	wire [23:0] wr_addr_with_bank;
	wire [23:0] cam_addr_with_bank;

	assign wr_addr_with_bank  = {bank_sel, wr_addr_fifo_datain[21:0]};
	assign cam_addr_with_bank = {bank_sel, cam_wr_addr[21:0]};

	wire wr_addr_fifo_wrreq_mux;
	wire [23:0] wr_addr_fifo_datain_mux;
	wire wr_data_fifo_wrreq_mux;
	wire [31:0] wr_data_fifo_datain_mux;

	assign wr_addr_fifo_wrreq_mux   = wr_addr_fifo_wrreq  | cam_wr_addr_valid;
	assign wr_addr_fifo_datain_mux  = wr_addr_fifo_wrreq  ? wr_addr_with_bank : cam_addr_with_bank;
	assign wr_data_fifo_wrreq_mux   = wr_data_fifo_wrreq  | cam_wr_data_valid;
	assign wr_data_fifo_datain_mux  = wr_data_fifo_wrreq  ? wr_data_fifo_datain : cam_wr_data;

	// Apply bank_sel to read addresses generated internally
	wire [23:0] read_addr_with_bank;
	assign read_addr_with_bank = {bank_sel, read_addr[21:0]};

	data_fifo wr_data_fifo (
		.data(wr_data_fifo_datain_mux),
		.wrreq(wr_data_fifo_wrreq_mux),
		.rdreq(wr_data_fifo_rdrequest),
		.wrclk(clk),
		.rdclk(clk),
		.aclr(~ar),
		.q(wr_data_fifo_dataout),
		.rdusedw(wr_data_fifo_rdusedw),
		.wrusedw(wr_data_fifo_wrusedw),
		.wrfull(wr_data_fifo_full),
		.rdempty(wr_data_fifo_empty)
	);

	
	data_fifo rd_data_fifo (
		.data(mem_rd_data),
		.wrreq(mem_rd_valid),
		.rdreq(rd_data_fifo_rdreq),
		.rdclk(clk_hdmi),
		.wrclk(clk),
		.aclr(~ar),
		.q(rd_data_fifo_dataout),
		.rdusedw(rd_data_fifo_rdusedw),
		.wrusedw(rd_data_fifo_wrusedw),
		.wrfull(rd_data_fifo_full),
		.rdempty(rd_data_fifo_empty)
	);

address_fifo wr_addr_fifo (
		.data  (wr_addr_fifo_datain_mux),
		.wrreq (wr_addr_fifo_wrreq_mux),
		.rdreq (wr_addr_fifo_rdreq),
		.clock (clk),
		.aclr  (~ar),
		.sclr  (~ar),
		.q     (wr_addr_fifo_dataout),
		.usedw (wr_addr_fifo_usedw),
		.full  (wr_addr_fifo_full),
		.empty (wr_addr_fifo_empty)
	);	
	

address_fifo rd_addr_fifo (
		.data  (read_addr_with_bank),
		.wrreq (rd_addr_fifo_wrreq),
		.rdreq (rd_addr_fifo_rdreq),
		.clock (clk),
		.aclr  (~ar),
		.sclr  (~ar),
		.q     (rd_addr_fifo_dataout),
		.usedw (rd_addr_fifo_usedw),
		.full  (rd_addr_fifo_full),
		.empty (rd_addr_fifo_empty)
	);	
	
	
	// FSM to control read requests through RD FIFO
	reg rd_addr_fifo_wrreq;
	reg [23:0] read_addr;
	reg [11:0] read_trans;   // Read transaction number
	parameter  READ_LEN = 512;
	parameter  READ_TRANSACTIONS = 480*1.25;  // 640x480: 640/512 = 1.25
	
	
	reg [2:0]  cs_read;
	reg	[3:0]	vsynch_sr;
	wire	vsynch_delayedge;
	reg	sdram_initdone;
	
	always @(negedge ar or posedge clk )
	if(~ar)
		vsynch_sr = 4'd0;
	else
		vsynch_sr = {vsynch_sr[2:0],vsynch};
	
	assign vsynch_delayedge = ~vsynch_sr[3] & vsynch_sr[2];
	
	always @(negedge ar or posedge clk )
	if(~ar)
		sdram_initdone = 1'b0;
	else	
		begin
		if(~mem_busy)
			sdram_initdone = 1'b1;
		end	
		
	parameter [2:0] Read_Idle=3'b000, Read_AddrWrite=3'b001, Read_Wait=3'b010, Read_Wait2=3'b011, Read_First=3'b100;
	
	always @(negedge ar or posedge clk )
	if(~ar)
	   begin
		cs_read = Read_Idle;
		rd_addr_fifo_wrreq = 1'b0;
		read_addr = 24'd0;
		read_trans = 12'd0;
	   end
	else
	   case(cs_read)
			Read_Idle:
			begin
				read_trans = 0;
				rd_addr_fifo_wrreq = 1'b0;
				read_addr = 0;
				cs_read = Read_Idle;
				
				if(vsynch_delayedge & sdram_initdone)
					begin
					rd_addr_fifo_wrreq = 1'b1;
					read_addr = read_addr + READ_LEN;
					read_trans = read_trans + 1;
					cs_read = Read_First;
					end
				else
					begin
					rd_addr_fifo_wrreq = 1'b0;
					read_addr = 24'd0;
					read_trans = 12'd0;
					end
			end	
			Read_First:
				begin
				rd_addr_fifo_wrreq = 1'b0;
				cs_read = Read_Wait;
				end
						
			Read_AddrWrite:
				begin
				rd_addr_fifo_wrreq = 1'b0;
				read_addr = read_addr + READ_LEN;
				read_trans = read_trans + 1;
				cs_read = Read_Wait;
				end
				
			Read_Wait:			
				begin
				rd_addr_fifo_wrreq = 1'b0;

				if(vsynch_delayedge & sdram_initdone)
					begin
					rd_addr_fifo_wrreq = 1'b1;
					read_addr = 24'b0;
					read_trans = 1;
					cs_read = Read_First;
					end

				if(rd_data_fifo_rdusedw >= 511)
					if(read_trans < READ_TRANSACTIONS)
						cs_read = Read_Wait2;
					else	
						cs_read = Read_Idle;
				end
				
			Read_Wait2:
				begin
				if(rd_data_fifo_rdusedw < 256)
					begin
					cs_read = Read_AddrWrite;
					rd_addr_fifo_wrreq = 1'b1;
					end
				end
				
			
			default:
				begin
				cs_read = Read_Idle;
				rd_addr_fifo_wrreq = 1'b0;
				read_addr = 24'd0;
				read_trans = 11'd0;
			end
		endcase	
				
	
	
	// Main manager FSM
	
	reg 	read_write_n;
	wire	read_start;
	wire	write_start;
	wire	rd_data_fifo_512words;
	wire	wr_data_fifo_512words;
	
	assign rd_data_fifo_512words = (rd_data_fifo_rdusedw >= 512) ? 1'b1 : 1'b0;
	assign wr_data_fifo_512words = (wr_data_fifo_wrusedw >= 512) ? 1'b1 : 1'b0;
	
	assign read_start  = ~mem_busy & ~rd_addr_fifo_empty & ~rd_data_fifo_512words;
	assign write_start = ~mem_busy & ~wr_addr_fifo_empty & wr_data_fifo_512words;
	
	assign mem_addr    = read_write_n ? rd_addr_fifo_dataout : wr_addr_fifo_dataout;
	assign mem_wr_data = wr_data_fifo_dataout;
	assign wr_data_fifo_rdrequest = mem_wr_next | wr_data_fifo_rdreq;
	
	parameter [3:0]	Idle = 4'h0,
					Start_Write = 4'h1,
					Get_First_Word = 4'h2,
					Wait_Write = 4'h3,
					Continue_Write = 4'h4,
					End_Write = 4'h5,
					Start_Read = 4'h6, 
					Wait_Read = 4'h7,
					Continue_Read = 4'h8;
					
					
	reg [3:0]   cs;
	reg [3:0] ctr;
	
	
	always @(negedge ar or posedge clk )
	if(~ar)
	   begin
		cs = Idle;
		read_write_n = 1'b0;
		ctr = 4'd0;
		mem_wr_req = 1'b0;
		mem_rd_req = 1'b0;
		wr_data_fifo_rdreq = 1'b0;
		rd_data_fifo_wrreq = 1'b0;
		wr_addr_fifo_rdreq = 1'b0;
		rd_addr_fifo_rdreq = 1'b0;
	   end
	else
	   case(cs)
			Idle:
				begin
				rd_addr_fifo_rdreq = 1'b0;
				
				 if(write_start)
				   begin
					read_write_n = 1'b0;
					wr_addr_fifo_rdreq = 1'b1;
					wr_data_fifo_rdreq = 1'b1;
					cs = Start_Write;
				   end
				 else
					if(read_start)
					   begin
						read_write_n = 1'b1;
						rd_addr_fifo_rdreq = 1'b1;
						cs = Start_Read;
					   end
					else
					   begin
							cs = Idle;
							read_write_n = 1'b0;
							ctr = 4'd0;
							mem_wr_req = 1'b0;
							mem_rd_req = 1'b0;
							wr_data_fifo_rdreq = 1'b0;
							rd_data_fifo_wrreq = 1'b0;
							wr_addr_fifo_rdreq = 1'b0;
							rd_addr_fifo_rdreq = 1'b0;
					   end
				end
				
			Start_Write:
				begin
					wr_addr_fifo_rdreq = 1'b0;
					wr_data_fifo_rdreq = 1'b0;
					mem_wr_req = 1'b1;
					ctr = 4'd0;
					cs = Wait_Write;
				end
			
			Wait_Write:
				begin
					mem_wr_req = 1'b0;

					if(mem_wr_next)
						begin
						cs = Continue_Write;
						end

				end
				
			Continue_Write:
				begin
				
				if(~mem_wr_next)
					begin
						ctr = 0;
						cs = Idle;
					end
					
				end
			
			End_Write:
				cs = Idle;

			Start_Read:  
				begin
					rd_addr_fifo_rdreq = 1'b0;
					mem_rd_req = 1'b1;
					ctr = 4'd0;
					cs = Wait_Read;
				end

			Wait_Read:
				begin
				mem_rd_req = 1'b0;
				
				if(mem_rd_valid)
					cs = Continue_Read;
				end

			Continue_Read:
				begin
				
				if(~mem_rd_valid)
					begin
						ctr = 0;
						cs = Idle;
					end
					
				end
	
					
		default:
			cs = Idle;
		
	endcase
         
            
	
	endmodule
