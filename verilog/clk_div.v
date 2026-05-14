
module    clk_div(ar, clk_in, clk_out);
    input ar, clk_in;
    output clk_out;
    reg   clk_out;
    parameter n = 14;      // Bit width of counter and limit
    parameter [n-1:0] limit = 14'd8333; // For 80 MHz input, 9600 Hz output
    reg [n-1:0]   count;
    
    
    always @(negedge ar or posedge clk_in)
    if(~ar)
       begin
           clk_out = 1'b0;
           count = 0;
       end
    else
       if(count >= limit)
          begin
              clk_out = ~clk_out;
              count = 0;
          end
       else
         count = count + 1;
         
 endmodule              
          
                 
    
    
    