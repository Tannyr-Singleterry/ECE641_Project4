module rs232_rx(ar, clk, clk_fast, din, show_prev, dout, ar_clkdiv, new_rx );
	input	ar;
	input	clk;
	input clk_fast;
	input	din;
	input 	show_prev;
	output [7:0] dout;
//	reg	[7:0] dout;
	output ar_clkdiv;
	output reg new_rx;
	
//	output [3:0] cs;

	reg    ar_clkdiv, ar_clkdiv_pre;
	
	reg[7:0]	d1, d2;
	
	parameter    StA = 1'b0, StB = 1'b1;
	reg   cs1, ns1;
	
	
   parameter [3:0] Idle=4'h0, Start=4'h1, D0=4'h2, D1=4'h3, D2=4'h4, D3=4'h5, 
		     D4=4'h6, D5=4'h7, D6=4'h8, D7=4'h9, Parity=4'hA, Stop=4'hB;

   reg [3:0]  cs;
   

	assign dout = show_prev ? d2 : d1;
	
	always @(negedge ar or posedge clk_fast)  // Mealy FSM example
	if(~ar)
	   begin
	   cs1 = StA;
	   ar_clkdiv = 1'b0;
	   end
	else
	   begin
      cs1 = ns1;
      ar_clkdiv = ar_clkdiv_pre;
      end
    
      
   always @(cs1 or cs or din)
      case(cs1)
          StA:
             if(cs == Idle && din == 1'b0)
               begin
                ns1 = StB;
                ar_clkdiv_pre = 1'b0;  // Output is ar_clkdiv_pre
               end
             else
               begin
                ns1 = StA;
                ar_clkdiv_pre = 1'b1;
               end     
               
           StB:
              if(cs == Idle)
                 begin
                    ns1 = StB;
                    ar_clkdiv_pre = 1'b1;
                end
              else
                 begin
                     ns1 = StA;
                     ar_clkdiv_pre = 1'b1;
                 end
       endcase
         
            
	always @(negedge ar or posedge clk)    // Moore FSM example
		if(~ar)
		  begin
			cs = Idle;
			new_rx = 1'b0;
			d1 = 8'b0;
			d2 = 8'b0;
		  end
		else
			case(cs)
				Idle :
					if(din == 1'b0)
						begin
							cs = Start;
							d2 = d1;
							new_rx = 1'b0;
						end
					else
						begin
						cs = Idle;
						new_rx = 1'b0;
						end
						
				Start :
					begin
						cs = D0;
						d1[0] = din;
					end
					
				D0 :
					begin
						cs = D1;
						d1[1] = din;
					end
	
				D1 :
					begin
						cs = D2;
						d1[2] = din;
					end
				D2 :
					begin
						cs = D3;
						d1[3] = din;
					end
				D3 :
					begin
						cs = D4;
						d1[4] = din;
					end
				D4 :
					begin
						cs = D5;
						d1[5] = din;
					end
				D5 :
					begin
						cs = D6;
						d1[6] = din;
					end
				D6 :
					begin
						cs = Stop;  // No parity
						d1[7] = din;
					end
					
				Parity :
					begin
						cs = Stop;
					end
					
				Stop :
					begin
						cs = Idle;
						new_rx = 1'b1;
					end
				
				default :
					if(din == 1'b0)
						cs = Start;
					else
						cs = Idle;
			endcase
	
	
	endmodule
	