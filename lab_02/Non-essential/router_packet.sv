package router_packet;

class packet_c;
    logic[3:0] sa;                       // source address
    logic[3:0] da;                      // destination address
    logic[7:0] payload[$];            // expected packet data array
endclass


/**********************************************************************************
*                                 monitor                                         *
*                                                                                 */
class monitor;
  
  logic[7:0] pkt2cmp_payload[$];      // actual packet data array
  logic[7:0] pkt1cmp_payload[$];      // send packet data array
  int m_da;
  int m_sa;
  int m_count;
  int m_scount;
  virtual router_io rtr_io;

  
  function new(virtual router_io intf);
	this.rtr_io = intf;
  endfunction
  
  task run();   
    //@(posedge rtr_io.reset_n);	
	// forever begin
	fork  
	  recv();
	  monsend();
	join
	check();
	// end
  endtask:run 
  
/***************************************************************************************************/  
  task recv();
	  get_payload();	
  endtask: recv

/***************************************************************************************************/  
  task monsend();
	  mon_payload();
  endtask: monsend


/***************************************************************************************************/
  task get_payload();
    
	pkt2cmp_payload.delete();
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
		  $display("MONITOR output [%0dth] payload %d", m_count, datum);
      	  return;      //done with payload            frame提前valid一个周期

      	end

      	else begin
      	  $display("\n%m\n[ERROR]%t Packet payload not byte aligned!\n", $realtime);
      	  $finish;
      	end
        @(rtr_io.cb);
      end

      pkt2cmp_payload.push_back(datum);
      m_count++;
	  $display("MONITOR output [%0dth] payload %d", m_count, datum);
    end

  endtask: get_payload
  
  /***************************************************************************************************/
  task mon_payload();
     
    pkt1cmp_payload.delete();
    fork
      begin: wd_timer_fork
      fork: frame_wd_timer
        @(negedge rtr_io.cb.frame_n[m_sa]); //this is a thread by itself
        begin                              //this is another thread
          repeat(1000) @(rtr_io.cb);
      	$display("\n%m\n[ERROR]%t Frame signal timed out!\n", $realtime);
          $finish;
        end
      join_any: frame_wd_timer
      disable fork;
      end: wd_timer_fork
    join

    forever begin
      logic[7:0] datum;
      for(int i=0; i<8; i=i)  begin //i=i prevents VCS warning messages
        if(!rtr_io.cb.valid_n[m_sa])
          datum[i++] = rtr_io.cb.din[m_sa];
        if(rtr_io.cb.frame_n[m_sa])
          if(i==8) begin //byte alligned
      	  pkt1cmp_payload.push_back(datum);
		  m_scount++;
		  $display("MONITOR  input [%0dth] payload %d", m_scount, datum);
      	  return;      //done with payload

      	end

      	else begin
      	  $display("\n%m\n[ERROR]%t Packet payload not byte aligned!\n", $realtime);
      	  $finish;
      	end
        @(rtr_io.cb);
      end

      pkt1cmp_payload.push_back(datum);
      m_scount++;
	  $display("MONITOR  input [%0dth] payload %d", m_scount, datum);
    end

  endtask: mon_payload


/***************************************************************************************************/
  function bit compare(ref string message);

    if(pkt1cmp_payload.size() != pkt2cmp_payload.size()) begin
      message = "Payload size Mismatch:\n";
      message = { message, $sformatf("payload.size() = %0d, pkt2cmp_payload.size() = %0d\n", pkt1cmp_payload.size(), pkt2cmp_payload.size()) };
      return (0);
    end
    if(pkt1cmp_payload == pkt2cmp_payload) ;
    else begin
      message = "Payload Content Mismatch:\n";
      message = { message, $sformatf("Packet Sent:   %p\nPkt Received:   %p", pkt1cmp_payload, pkt2cmp_payload) };
      return (0);
    end
    message = "Successfully Compared";
    return(1);
  endfunction: compare

/***************************************************************************************************/
  task check();
    string message;
    static int pkts_checked = 1;

    if (!compare(message)) begin
      $display("\n%m\n[ERROR]%t Packet #%0d %s\n", $realtime, pkts_checked, message);
      $finish;
    end
    $display("[NOTE]%t Packet #%0d %s", $realtime, pkts_checked++, message);
  endtask: check


endclass:monitor



/**********************************************************************************
*                             stimulator                                          *
*                                                                                 */
    
class stimulator;
  // import router_packet::*;
  int run_for_n_packets;      // number of packets to test
  int m_sa;
  int m_da;
  int m_bytes;
  int i=0;
  packet_c pkt;
  
  
  virtual router_io.TB rtr_io; //  only can  get interface's point
  
  function new(virtual router_io.TB intf);
	this.rtr_io = intf;
  endfunction

/***************************************************************************************************/
  task run();
    //@(posedge rtr_io.reset_n);
	// for(int i=1; i<=run_for_n_packets; i++) begin
	    i++;
    	gen(pkt);                            //     
	    send(pkt);
        m_bytes += pkt.payload.size();	   
	    $display("STIMULATOR sends [%0dth]packer SA = %0d, DA = %0d, PAYLOADS = %p", i, pkt.sa, pkt.da, pkt.payload);  
	// end
	// repeat(50) @(rtr_io.cb);
	// $display("send totally [%0d] data", m_bytes);	
    // $finish;
  endtask: run

/***************************************************************************************************/
  task gen(output packet_c pkt);
	pkt = new();
	pkt.sa = m_sa;//$urandom
	pkt.da = m_da;//
	pkt.payload.delete(); //clear previous data
	repeat($urandom_range(4,2))
	  pkt.payload.push_back($urandom);

  endtask: gen

/***************************************************************************************************/  
  task send(input packet_c pkt);
  
	send_addrs(pkt);
	send_pad(pkt);
	send_payload(pkt);

  endtask: send
 
/***************************************************************************************************/
  task send_addrs(input packet_c pkt);
    
	rtr_io.cb.frame_n[pkt.sa] <= 1'b0; //start of packet
	for(int i=0; i<4; i++) begin
	  rtr_io.cb.din[pkt.sa] <= pkt.da[i]; //i'th bit of da
	  @(rtr_io.cb);
	end

  endtask: send_addrs
 
/***************************************************************************************************/
  task send_pad(input packet_c pkt);
  
	rtr_io.cb.frame_n[pkt.sa] <= 1'b0;
	rtr_io.cb.din[pkt.sa] <= 1'b1;
	rtr_io.cb.valid_n[pkt.sa] <= 1'b1;
	repeat(5) @(rtr_io.cb);

  endtask: send_pad
 
/***************************************************************************************************/
  task send_payload(input packet_c pkt);
  
	foreach(pkt.payload[index])
	  for(int i=0; i<8; i++) begin
	    rtr_io.cb.din[pkt.sa] <= pkt.payload[index][i];
		rtr_io.cb.valid_n[pkt.sa] <= 1'b0; //driving a valid bit
		rtr_io.cb.frame_n[pkt.sa] <= ((i == 7) && (index == (pkt.payload.size() - 1)));
		@(rtr_io.cb);
	  end
	rtr_io.cb.valid_n[pkt.sa] <= 1'b1;
	
  endtask: send_payload


endclass:stimulator




/**********************************************************************************
*                                test                                       *
*                                                                                 */
class test;
  
  stimulator stim;
  monitor mon;
  int flog=9;
  
  virtual router_io.TB intf;
  
  function new(virtual router_io.TB intf);
	this.intf = intf;
	stim = new(intf);
	mon = new(intf);
  endfunction
 
  task run();

	m_config();
    reset();	
	for(int i=1; i<=stim.run_for_n_packets; i++) begin
	
	fork  
	  mon.run();
	  stim.run();
	join	
	$display("***************************************************************");
	// f_config();
	
	end
	
	repeat(50) @(intf.cb);
	$finish;
	
  endtask:run

  
/***************************************************************************************************/  
  task reset();
    #20
	intf.reset_n = 1'b0;
    intf.cb.frame_n <= '1;
    intf.cb.valid_n <= '1;
    #40 intf.reset_n <= 1'b1;
    repeat(15) @(intf.cb);
	
  endtask: reset


/***************************************************************************************************/
  task m_config();
    
	stim.m_sa = $urandom_range(0,15);
	stim.m_da = $urandom_range(0,15);
	stim.run_for_n_packets = 10;
	mon.m_da = stim.m_da;
    mon.m_sa = stim.m_sa;
    $display("----------------t%0d----input----%0d-------------------",flog,stim.m_sa);
	$display("----------------t%0d----output----%0d-------------------",flog,stim.m_da);
  endtask
 
/***************************************************************************************************/ 
  task f_config();    
	stim.m_sa = $urandom_range(0,15);
	stim.m_da = $urandom_range(0,15);
	mon.m_da = stim.m_da;
    mon.m_sa = stim.m_sa;
    $display("----------------t%0d----input----%0d-------------------",flog,stim.m_sa);
	$display("----------------t%0d----output----%0d-------------------",flog,stim.m_da);
  endtask
  
endclass: test

endpackage:router_packet