`timescale 1ns/100ps
`include "router_io.sv"
module router_test_top;
  parameter simulation_cycle = 100;

  bit SystemClock;
  router_io intf_io(SystemClock);
  
  import router_packet::*;
  // test tb(intf_io);
  
  router dut(
    .reset_n	(intf_io.reset_n),
    .clock	    (intf_io.clock),
    .din	    (intf_io.din),
    .frame_n	(intf_io.frame_n),
    .valid_n	(intf_io.valid_n),
    .dout	    (intf_io.dout),
    .valido_n	(intf_io.valido_n),
    .busy_n	    (intf_io.busy_n),
    .frameo_n	(intf_io.frameo_n)
  );

  initial begin
    $timeformat(-9, 1, "ns", 10);
    SystemClock = 0;
    forever begin
      #(simulation_cycle/2)
        SystemClock = ~SystemClock;
    end
  end

  initial begin
    test t1,t2;
	t1 = new(intf_io);
	t2 = new(intf_io);
	t1.flog=1;
	t2.flog=2;
	
	fork
	  t1.run();
      t2.run();
	join
  end
  
endmodule
