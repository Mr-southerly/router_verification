package pkg_a; 
	class packet_a; 
		int pkg_a; 
	endclass 
	
	typedef struct{
		int data; 
		int command;
	} struct_a; 
	
	int va=1; 
	int shared=10; 
endpackage 

package pkg_b; 
	class packet_b; 
		int pkg_b; 
	endclass 
	
	typedef struct{
		int data; 
		int command;
	} struct_b; 
	
	int vb=2; 
	int shared=20; 
endpackage

module tb2;
	// import pkg_a::packet_a;
	// import pkg_b::packet_b;
	import pkg_b::shared; 
	
	class packet_tb;
	endclass
	
	typedef struct{
		int data; 
		int command;
	} struct_tb;

	class  packet_a;
		int tb_a;
	endclass
	
	class  packet_b;
		int tb_b;
	endclass
	
	initial begin
		pkg_a::packet_a pa=new();
		pkg_b::packet_b pb=new();
		packet_tb ptb=new();
		$display("pkt_a::va=%0d, pkt_b::vb=%0d,",pkg_a::va ,pkg_b::vb);
		$display("shared=%0d", pkg_b::shared);
	end
endmodule
	