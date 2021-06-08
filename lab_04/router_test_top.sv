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
  
  base_test tests[string]; 
  automatic single_channel_directed_da_test t1 = new(intf_io); 
  automatic dual_channel_directed_da_test t2 = new(intf_io); 
  automatic dual_channel_random_da_test t3 = new(intf_io);
  automatic all_channel_random_da_test t4 = new(intf_io); 
  

  string name; 
  tests["single_channel_directed_da_test"] = t1; 
  tests["dual_channel_directed_da_test"] = t2; 
  tests["dual_channel_random_da_test"] = t3;
  tests["all_channel_random_da_test"] = t4;
  
  if($value$plusargs("TESTNAME=%s",name)) begin 
	if (tests.exists(name)) begin 
			tests[name].build(); 
			tests[name].connect(); 
			tests[name].run(); 

	end 
	else begin 
		$fatal("[ERRTEST], test name %s is invalid, please specify a valid name!", name); 
	end
  end
  else begin
	$display("NO runtime optiont +TESTNAME-xxx is configured, and run default test single_channel_directed_da_test"); 
	tests["single_channel_directed_da_test"].build(); 
	tests["single_channel_directed_da_test"].connect(); 
	tests["single_channel_directed_da_test"].run();
  end

  end

endmodule
