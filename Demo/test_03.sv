module tb; 
class randnum; 
  rand bit[3:0]x,y; 
endclass 

initial begin 
randnum rn=new(); 
int x=5,y=7; 

for(int loop=0; loop<10; loop++) begin 
  rn.randomize() with {x<y;};
  $display("LOOP-%0d: CONSTRAINT{x<y;}\n rn.x=%0d, rn.y=%0d", loop, rn.x, rn.y); 
  rn.randomize() with {x< this.y;};
  $display("LOOP-%0d: CONSTRAINT{x<this.y;}\n rn.x=%0d, rn.y=%0d", loop, rn.x, rn.y); 
  rn.randomize() with {x< local::y;};
  $display("LOOP-%0d: CONSTRAINT{x<local::y;}\n rn.x=%0d, rn:y=%0d", loop, rn.x, rn.y);
end
end
endmodule