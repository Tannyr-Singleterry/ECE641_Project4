module rs232_tx(ar, clk, tx_start, tx_done, tx_word, tx_out );
	input	ar;
	input	clk;
	input	tx_start;
	output reg	tx_done;
	input [7:0] tx_word;
	output  tx_out;

	reg [9:0]	tx_sr;  // {Start, data[7:0], Stop}
	
	assign tx_out = tx_sr[0];
	
	
	always @(negedge ar or posedge clk)    // Moore FSM example
		if(~ar)
		  begin
			tx_sr = 10'hfff;
			
		  end
		else
			begin
				if(ld)
					tx_sr = {1'b1, tx_word, 1'b0};
				else if(sh)
					tx_sr = {1'b1, tx_sr[9:1]};
			end
			
		
		
		
	reg [3:0] ctr;
	reg	ld, sh;
	
   parameter [1:0] Idle=2'd0, Load_Sr=2'd1, Shift=2'd2, Finish=2'd3;
   reg [1:0]  cs;
   

            
	always @(negedge ar or posedge clk)    // Moore FSM example
		if(~ar)
		  begin
			cs = Idle;
			ctr = 4'd0;
			ld = 1'b0;
			sh = 1'b0;
		  end
		else
			case(cs)
				Idle :
					if(tx_start)
						begin
							cs = Load_Sr;
							ld = 1'b1;
						end
					else
						begin
						cs = Idle;
						ld = 1'b0;
						sh = 1'b0;
						end
						
				Load_Sr :
					begin
						cs = Shift;
						ld = 1'b0;
						sh = 1'b1;
					end
					
				Shift :
					begin
						if(ctr >= 9)
							begin	
							cs = Finish;
							sh = 1'b0;
							tx_done = 1'b1;
							end
						else
							begin
							cs = Shift;
							sh = 1'b1;
							ctr = ctr + 1;
							end
												
					end
	
				Finish :
					begin
						cs = Idle;
						tx_done = 1'b0;
						ctr = 4'd0;
					end
				
				default :
						cs = Idle;
			endcase
	
	
	endmodule
	