class packet; 
	integer i=1; 
	integer m=2; 
	
	function new(int val); 
		i=val+1;
	endfunction
	
	function shift();
		i=i<<1; 
	endfunction 
endclass 

class linkedpacket extends packet; 
	integer i=3; 
	integer k=5; 
	
	
	function new(int val); 
		super.new(val); 
		if(val>=2)
			i=val; 
	endfunction 
	function shift(); 
		super.shift(); 
		i=i<<2; 
	endfunction 
endclass 

module tb_01; 
	initial begin
	packet p = new(3); 		
	linkedpacket lp=new(1); 
	packet tmp; 
	tmp=lp; 
	$display("*******p.i=%0d*********",p.i);
	$display("*******lp.i=%0d*********",lp.i);
	$display("*******lp.m=%0d*********",lp.m);
	$display("*******tmp.i=%0d*********",tmp.i);

end endmodule
