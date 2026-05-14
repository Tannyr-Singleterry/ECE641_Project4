module int_line (
		input  wire [9:0]  data,      //      data.datain,    Data input of the memory.The data port is required for all RAM operation modes:SINGLE_PORT,DUAL_PORT,BIDIR_DUAL_PORT,QUAD_PORT
		output wire [9:0]  q,         //         q.dataout,   Data output from the memory
		input  wire [11:0] wraddress, // wraddress.wraddress, Write address input to the memory.
		input  wire [11:0] rdaddress, // rdaddress.rdaddress, Read address input to the memory.
		input  wire        wren,      //      wren.wren,      Write enable input for address port.The wren signal is required for all RAM operation modes:SINGLE_PORT,DUAL_PORT,BIDIR_DUAL_PORT,QUAD_PORT
		input  wire        wrclock,   //   wrclock.clk
		input  wire        rdclock    //   rdclock.clk
	);
endmodule

