
module D8M_WRITE_COUNTER (	
  input	[11:0]	iDATA,		
  input			   iFVAL,	// MIPI VS
  input			   iLVAL,  // MIPI HS
  input			    iCLK,  // CCD Pixel CLK
  input			    iRST,
  output	reg [15:0]	X_Cont,
  output	reg [15:0]	Y_Cont,  
  output	reg [15:0]	X_TOTAL,
  output	reg [15:0]	Y_TOTAL,  
  output	reg [15:0]	X_WR_CNT
);
	
parameter D8M_LINE_CNT  =  792 ; //792from signaltape 
parameter FREE_RUN      =  44; 
	
reg				Pre_FVAL;
reg				Pre_LVAL;


always@(posedge iCLK or negedge iRST)
begin
	if(!iRST)
		begin
		Pre_FVAL	<=iFVAL;
		Pre_LVAL	<=iLVAL;
		X_Cont	<=	0;
		Y_Cont	<=	0;
		X_WR_CNT <= 0; 
		end
	else
		begin
		Pre_FVAL	<=	iFVAL;
		Pre_LVAL	<=	iLVAL;
		
		if  ( Pre_LVAL & !iLVAL)   // Falling edge on HS
		   X_WR_CNT <=   0; 
		else 	
			if ( iLVAL ) 
				X_WR_CNT <=  X_WR_CNT +1;   // Count since HS=1
		
      		
		//------------------------------		
		if   ( Pre_FVAL & !iFVAL) // Falling edge on VS
			{ Y_TOTAL , Y_Cont }  	<=	{ Y_Cont ,16'h0  } ;  
		else 
			if   ( Pre_LVAL & !iLVAL) begin  // falling edge on HS
				Y_Cont	  <=	 Y_Cont +1; 
				{ X_TOTAL , X_Cont }  	<=	{ X_Cont ,16'h0  } ;
				end
			else  
				if ( ( Y_Cont <=  FREE_RUN  ) && ( X_Cont	== D8M_LINE_CNT )) begin  // Y <=44 & X==792
					Y_Cont	<=	 Y_Cont +1; 
					X_Cont	<=	 0; 			
					end 
				else 	
					X_Cont	<=	 X_Cont +1; 		
	end
end


endmodule
