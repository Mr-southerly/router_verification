`timescale 1ns/100ps


  typedef struct
  {
    logic[3:0] sa;                        // source address
    logic[3:0] da;                        // destination address
    logic[7:0] payload[$];              // expected packet data array
  }packet_t_s;
  
/**********************************************************************************
*                                                                                 *
*                             stimulator                                          *
*                                                                                 *
**********************************************************************************/
    
module stimulator(router_io.TB rtr_io);
  
  int run_for_n_packets;      // number of packets to test
  int m_sa;
  int m_da;
  int m_bytes;
  packet_t_s pkt;
  
  initial begin
    
	m_config();
  	reset();
	for(int i=1; i<=run_for_n_packets; i++) begin
	  gen(pkt);                            //     
	  send(pkt);
      m_bytes += pkt.payload.size();	   
	  $display("STIMULATOR sends [%0dth]packer SA = %0d, DA = %0d, PAYLOADS = %p", i, pkt.sa, pkt.da, pkt.payload);
	end
	repeat(50) @(rtr_io.cb);
	$display("totally [%0d] data", m_bytes);
    $finish;
  end


/***************************************************************************************************/  
  task reset();
    
	#20;
	rtr_io.reset_n = 1'b0;
    rtr_io.cb.frame_n <= '1;
    rtr_io.cb.valid_n <= '1;
    #2 rtr_io.cb.reset_n <= 1'b1;
    repeat(15) @(rtr_io.cb);
	
  endtask: reset


/***************************************************************************************************/
  task automatic gen(output packet_t_s pkt);

	pkt.sa = m_sa;//$urandom
	pkt.da = m_da;//
	pkt.payload.delete(); //clear previous data
	repeat($urandom_range(4,2))
	  pkt.payload.push_back($urandom);

  endtask: gen

  
/***************************************************************************************************/  
  task automatic send(input packet_t_s pkt);
  
	send_addrs(pkt);
	send_pad(pkt);
	send_payload(pkt);

  endtask: send
 
 
/***************************************************************************************************/
  task automatic send_addrs(input packet_t_s pkt);
  
	rtr_io.cb.frame_n[pkt.sa] <= 1'b0; //start of packet
	for(int i=0; i<4; i++) begin
	  rtr_io.cb.din[pkt.sa] <= pkt.da[i]; //i'th bit of da
	  @(rtr_io.cb);
	end

  endtask: send_addrs
 
 
/***************************************************************************************************/
  task automatic send_pad(input packet_t_s pkt);
  
	rtr_io.cb.frame_n[pkt.sa] <= 1'b0;
	rtr_io.cb.din[pkt.sa] <= 1'b1;
	rtr_io.cb.valid_n[pkt.sa] <= 1'b1;
	repeat(5) @(rtr_io.cb);

  endtask: send_pad
 
 
/***************************************************************************************************/
  task automatic send_payload(input packet_t_s pkt);
  
	foreach(pkt.payload[index])
	  for(int i=0; i<8; i++) begin
	    rtr_io.cb.din[pkt.sa] <= pkt.payload[index][i];
		rtr_io.cb.valid_n[pkt.sa] <= 1'b0; //driving a valid bit
		rtr_io.cb.frame_n[pkt.sa] <= ((i == 7) && (index == (pkt.payload.size() - 1)));
		@(rtr_io.cb);
	  end
	rtr_io.cb.valid_n[pkt.sa] <= 1'b1;
	
  endtask: send_payload


/***************************************************************************************************/
  task m_config();
    
	stim.m_sa = $urandom;
	stim.m_da = $urandom;
	stim.run_for_n_packets = 20;
	mon.m_da = stim.m_da;
  endtask
  
endmodule  

/**********************************************************************************
*                                                                                 *
*                                 monitor                                         *
*                                                                                 *
**********************************************************************************/
module monitor(router_io.TB rtr_io);
  
  logic[7:0] pkt2cmp_payload[$];      // actual packet data array
  int m_da;
  int m_count;
  
  initial begin
    
    @(posedge rtr_io.reset_n)    
	recv();
  end
/***************************************************************************************************/  
  task recv();
  
	forever get_payload();
	
  endtask: recv


/***************************************************************************************************/
  task get_payload();
  
    //pkt2cmp_payload.delete();
	
    fork
      begin: wd_timer_fork
      fork: frameo_wd_timer
        @(negedge rtr_io.cb.frameo_n[m_da]); //this is a thread by itself
        begin                              //this is another thread
          repeat(1000) @(rtr_io.cb);
      	$display("\n%m\n[ERROR]%t Frame signal timed out!\n", $realtime);
          $finish;
        end
      join_any: frameo_wd_timer
      disable fork;
      end: wd_timer_fork
    join

    forever begin
      logic[7:0] datum;
      for(int i=0; i<8; i=i)  begin //i=i prevents VCS warning messages
        if(!rtr_io.cb.valido_n[m_da])
          datum[i++] = rtr_io.cb.dout[m_da];
        if(rtr_io.cb.frameo_n[m_da])
          if(i==8) begin //byte alligned
      	  pkt2cmp_payload.push_back(datum);
		  m_count++;
		  $display("MONITOR received output [%0dth] payload %d", m_count, datum);
      	  return;      //done with payload
      	end

      	else begin
      	  $display("\n%m\n[ERROR]%t Packet payload not byte aligned!\n", $realtime);
      	  $finish;
      	end
        @(rtr_io.cb);
      end
      pkt2cmp_payload.push_back(datum);
      m_count++;
	  $display("MONITOR received output [%0dth] payload %d", m_count, datum);
    end
  endtask: get_payload

endmodule



/**********************************************************************************
*                                                                                 *
*                                        test                                     *
*                                                                                 *
**********************************************************************************/
module test(router_io.TB intf);

  stimulator stim(intf);
  
  monitor mon(intf);

endmodule: test
