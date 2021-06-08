
package router_packet;

parameter CHNL_NUM = 16;
parameter bit TRACE_ON = 1;
parameter bit ERROR_STOP = 1;
parameter time TEST_DONE_DRAIN_TIME = 3000;

semaphore test_stop_keys = new(CHNL_NUM);        //Use semaphore to complete the multi-channel simultaneous input

typedef class packet_c;                         //Preliminary statement
typedef mailbox #(packet_c) pkt_mbox;           //Preliminary statement ,Used to transfer detection data

/**********************************************************************************
*                               data packet                                       *
*                                                                                 */
class packet_c;
    rand logic[3:0] sa;                       // source address
    rand logic[3:0] da;                       // destination address
    rand logic[7:0] payload[$];               // expected packet data array
	
	constraint cstr{                          // Constraint packet size
      payload.size inside {[2:4]};          
    }
      
   function bit compare(packet_c cmp,output string message);             //compare function 

      if(payload.size()!=cmp.payload.size()) begin
        message = "Payload size Mismatch:\n";
        message = { message, $psprintf("payload.size() = %0d, pkt2cmp.payload.size() = %0d\n", payload.size(), cmp.payload.size()) };
        return (0);
      end
      if(payload != cmp.payload)begin
        message = "Payload Content Mismatch:\n";
        message = { message, $psprintf("Packet Sent:   %p\nPkt Received:   %p", payload, cmp.payload) };
        return (0);
      end
      message = "Successfully Compared";
      return(1);
    endfunction:compare
   
    function string sprint();                                       //print function
      sprint=$sformatf("SA=%0d,DA=%0d \n",sa,da);
    endfunction:sprint
   
endclass: packet_c


/**********************************************************************************
*                              data generator                                     *
*                                                                                 */
class src_generator;
    int pkt_num;
	int id;
	int da;
	pkt_mbox src_pkt_mbox;
	packet_c src_pkt;
	
	static int pkts_generated;
	function new(int id=0,int da=-1,int pkt_num=10);      //input address and data parameters
	    this.id = id;
	    this.da = da;
        this.pkt_num = pkt_num;
	    src_pkt_mbox=new(1);
	endfunction:new
	
    virtual task gen();
	    src_pkt = new();
        void '(src_pkt.randomize() with {sa==local::id; da>=0 -> da==local::da;});
        src_pkt_mbox.put(src_pkt);	   //monitoring input data from generator is not good
	endtask:gen
	
	virtual task run();
	    test_stop_keys.get();         //we have totally 16 keys, so we can generate 16 packets at the same time
		repeat(pkt_num)begin          //repeat the package num 
		    this.gen();
		end
		test_stop_keys.put();
	endtask:run
	 
endclass:src_generator

/**********************************************************************************
*                              data stimulator                                    *
*                                                                                 */
class src_stimulator;
  
  int bytes_sent;
  int packets_send;
  int id;
   
  pkt_mbox src_pkt_mbox;           
 // pkt_mbox exp_pkt_mbox;
  
  virtual router_io.TB rtr_io;   
  packet_c pkt;
  
  function new(virtual router_io.TB rtr_io, int id = 0);
    this.rtr_io = rtr_io;	
	this.id=id;
  endfunction:new
  
  task run();
	@(posedge rtr_io.cb.reset_n);
	forever begin
	   src_pkt_mbox.get(pkt);
	   send(pkt);
	   bytes_sent += pkt.payload.size();
	   $display("SRC_STIMULATOR [%0d] sends [%0dth] packet SA=%0d,DA=%0d,PAYLOADS=%p",id, ++packets_send, pkt.sa, pkt.da, pkt.payload);
	end
  endtask:run
  
  task send(input packet_c pkt);           //send all data function 
  
    packet_c exp_pkt=new pkt;
	
    send_addrs(pkt);
	send_pad(pkt);
	send_payload(pkt);
	
	//exp_pkt_mbox.put(exp_pkt);         //monitoring input data from stimulator is not good
	
  endtask:send
  
  task send_addrs(input packet_c pkt);
    rtr_io.cb.frame_n[pkt.sa] <= 1'b0;
	for(int i=0;i<4;i++)begin
	    rtr_io.cb.din[pkt.sa] <= pkt.da[i];
		@(rtr_io.cb);
	end
  endtask:send_addrs
  
  task send_pad(input packet_c pkt);
    rtr_io.cb.frame_n[pkt.sa]<=1'b0;
	rtr_io.cb.valid_n[pkt.sa]<=1'b1;
	rtr_io.cb.din[pkt.sa]<=1'b1;
	repeat(5) @(rtr_io.cb);
  endtask:send_pad
 
  task send_payload(input packet_c pkt);
    foreach(pkt.payload[index])
	   for(int i=0;i<8;i++)begin
	    rtr_io.cb.din[pkt.sa] <= pkt.payload[index][i];
		rtr_io.cb.valid_n[pkt.sa] <= 1'b0;
		rtr_io.cb.frame_n[pkt.sa]<=((i==7)&&(index==(pkt.payload.size()-1)));
		@(rtr_io.cb);
       end	
	rtr_io.cb.valid_n[pkt.sa] <= 1'b1;
  endtask:send_payload
  
endclass:src_stimulator


/**********************************************************************************
*                       Destination data monitor                                  *
*                                                                                 */
class dst_monitor;
   int bytes_received;
   int id;
   logic[7:0] payload_out_q[$];
   virtual router_io.TB rtr_io;
   pkt_mbox act_dst_mbox=new();   //must use new function
   
  function new(virtual router_io.TB rtr_io,int id=0);
    this.rtr_io = rtr_io;
    this.id = id;	
  endfunction:new
  
  task run();
    @(posedge rtr_io.reset_n);
    recv();
  endtask:run

  task recv();
    forever begin 
	   get_payload();
	   write_trans();
	end 
  endtask:recv

  task get_payload();
    payload_out_q.delete();
	fork
	  begin: wd_timer_fork
	    fork:frameo_wd_timer
		  @(negedge rtr_io.cb.frameo_n[id]);
		  begin
		    repeat(5000) @(rtr_io.cb);
			$display("\n%m\n[ERROR]%t Frame signal timed out!\n", $realtime);
			$finish;
		  end 
		join_any:frameo_wd_timer
		disable fork;
	  end: wd_timer_fork
	join
	
    forever begin
      logic[7:0] datum;
      for(int i=0; i<8; i=i)begin 
        if(!rtr_io.cb.valido_n[id])
          datum[i++] = rtr_io.cb.dout[id];
        if(rtr_io.cb.frameo_n[id])
          if(i==8) begin 
      	    payload_out_q.push_back(datum);
			bytes_received++;
			if(TRACE_ON) $display("DST_MONITOR[%0d] received output [%0dth] payload %d",id,bytes_received,datum);		
      	    return;      
      	  end
          else begin
      	    $display("\n%m\n[ERROR]%t Packet payload not byte aligned!\n", $realtime);
      	    $finish;
      	  end
        @(rtr_io.cb);
      end
      payload_out_q.push_back(datum);
	  bytes_received++;	  
	  $display("DST_MONITOR[%0d] received output [%0dth] payload %d",id,bytes_received,datum);
    end
  		
  endtask:get_payload
  task write_trans();
    packet_c act_pkt=new();
	act_pkt.da=id;
	act_pkt.payload=payload_out_q;
	act_dst_mbox.put(act_pkt);

  endtask:write_trans

endclass:dst_monitor



/**********************************************************************************
*                         Source data monitor                                     *
*                                                                                 */
class src_monitor;
   int bytes_send;
   int id;
   logic[7:0] payload_put_q[$];
   logic[3:0] da;                      // destination address
   virtual router_io.TB rtr_io;
   pkt_mbox act_src_mbox;
   
  function new(virtual router_io.TB rtr_io,int id=0);
    this.rtr_io = rtr_io;
    this.id = id;	
  endfunction:new
  
  task run();
    @(posedge rtr_io.reset_n);
    recv();
  endtask:run

  task recv();
    forever begin 
	   get_payload();
	   write_trans();
	end 
  endtask:recv

  task get_payload();
    payload_put_q.delete();
	fork
	  begin: wd_timer_fork
	    fork:frame_wd_timer
		  @(negedge rtr_io.cb.frame_n[id]);       //#1  wait negedge
		  
		  begin
		    repeat(5000) @(rtr_io.cb);            //#2 time out 
			$display("\n%m\n[ERROR]%t Frame signal timed out!\n", $realtime);
			$finish;
		  end 
		join_any:frame_wd_timer
		disable fork;
	  end: wd_timer_fork
	join
	

	  for(int i=0; i<4; i=i)begin              //get 4-bit address
        if(!rtr_io.cb.frame_n[id])
          da[i++] = rtr_io.cb.din[id];
		@(rtr_io.cb);
      end	  

    forever begin
	  logic[7:0] datum;
      for(int i=0; i<8; i=i)begin              //get 8-bit bytes
        if(!rtr_io.cb.valid_n[id])
          datum[i++] = rtr_io.cb.din[id];
        if(rtr_io.cb.frame_n[id])
          if(i==8) begin 
      	    payload_put_q.push_back(datum);
			bytes_send++;
			if(TRACE_ON) $display("SRC_MONITOR[%0d] received input [%0dth] payload %d",id,bytes_send,datum);		
      	    return;      
      	  end
          else begin
      	    $display("\n%m\n[ERROR]%t Packet payload not byte aligned!\n", $realtime);
      	    $finish;
      	  end
        @(rtr_io.cb);
      end
      payload_put_q.push_back(datum);
	  bytes_send++;	  
	  $display("SRC_MONITOR[%0d] received input [%0dth] payload %d",id,bytes_send,datum);	  
    end
  		
  endtask:get_payload
  task write_trans();
    packet_c act_pkt=new();
	act_pkt.sa=id;
	act_pkt.da=da;
	act_pkt.payload=payload_put_q;
	act_src_mbox.put(act_pkt);	
  endtask:write_trans

endclass:src_monitor


/**********************************************************************************
*                             compared data                                       *
*                                                                                 */
class scoreboard;
    string name;
	int check_count;
	int error_count;
	bit test_pass_flag;
	event check_done;
	pkt_mbox act_src_mbox;    

	pkt_mbox act_src_mboxs[CHNL_NUM];    //expexted data by stim 
	pkt_mbox act_dst_mboxs[CHNL_NUM];    //actually data by monitor 
	
	function new(string name="scoreboard");
	   this.name=name;
	   test_pass_flag=1;
	   act_src_mbox=new();
	   foreach(act_src_mboxs[i])begin
	    act_src_mboxs[i]=new();
		act_dst_mboxs[i]=new();
	   end
	endfunction:new
	
	task run();
	  fork
	    dispatch_src_packet();
	  join_none
	  foreach(act_src_mboxs[i])begin
	    automatic int id=i;
		fork
		  check_dst_packet(id);
		join_none
	  end
	endtask:run
	
	task dispatch_src_packet();
	   packet_c acsrc_pkt=new();
	   forever begin
	    act_src_mbox.get(acsrc_pkt);     //data send by monitor
		act_src_mboxs[acsrc_pkt.da].put(acsrc_pkt);   // put data into expected mbox  as da'order
	   end
	endtask:dispatch_src_packet
	
    task check_dst_packet(int id);
	  packet_c src_pkt;
	  packet_c act_pkt;
	  
	  string message;
      forever begin
	    fork
		  act_src_mboxs[id].get(src_pkt);
		  act_dst_mboxs[id].get(act_pkt);
		join
		
		check_count++;

		if(!src_pkt.compare(act_pkt, message))begin
		  $display("\n%m\n[ERROR]%t Packet #%0d %s\n", $time, check_count, message);
		  $display("SRC_PKT content is \n %s", src_pkt.sprint());
          $display("ACT_PKT content is \n %s", act_pkt.sprint());
		  error_count++;
		  if(ERROR_STOP) $stop();
		end
		else begin
		  $display("[NOTE]%t Packet #%0d %s",$time, check_count, message);
		end
	  end

    endtask:check_dst_packet
	
	function void report();
	   $display("========================SCOREBOARD REPORT===============================");
	   $display("%s totally compared %0d packets",name,check_count);
	   if(error_count>0)begin
	    test_pass_flag=0;
		$display("ERROR:%s caught failure packet comparing!",name,error_count);
	   end
	   foreach(act_src_mboxs[i])begin
	     if(act_src_mboxs[i].num()>0)begin
		   $display("ERROR:act_src_mboxs[%0d] still has %0d packet not compared!",i,act_src_mboxs[i].num());
		   test_pass_flag=0;
	     end
	     if(act_dst_mboxs[i].num()>0)begin
		   $display("ERROR:act_dst_mboxs[%0d] still has %0d packet not compared!",i,act_dst_mboxs[i].num());
		   test_pass_flag=0;
	     end
	   end 
	   $display("========================================================================");
	endfunction:report
    
endclass:scoreboard

/**********************************************************************************
*                                 data struct                                     *
*                                                                                 */

typedef struct{
   rand int sa;
   rand int da;
   rand int pkt_num;
}chnl_config_t;


/**********************************************************************************
*                                base_test                                        *
*                                                                                 */
class base_test;
   
   rand chnl_config_t chnl_cfg[CHNL_NUM];
   string name;
    
   rand bit[3:0] chnl_da[CHNL_NUM];	
   src_generator src_gen[CHNL_NUM];
   src_stimulator src_stim[CHNL_NUM];
   dst_monitor  dst_mon[CHNL_NUM];
   src_monitor  src_mon[CHNL_NUM];
   scoreboard  sb;
   virtual router_io.TB rtr_io;
   
   function new(virtual router_io.TB rtr_io);
    this.rtr_io = rtr_io;		
	this.name = "base_test";
   endfunction:new
   
   virtual function void build();
     do_config();
	 foreach(src_gen[i])begin
    	src_gen[i] = new(chnl_cfg[i].sa, chnl_cfg[i].da, chnl_cfg[i].pkt_num);
    	src_stim[i] = new(rtr_io, chnl_cfg[i].sa);
    	dst_mon[i] = new(rtr_io, i);
		src_mon[i] = new(rtr_io, i);
     end
	 sb=new();     
   endfunction:build
   
   virtual function void connect();
    foreach(src_gen[i])begin
       src_stim[i].src_pkt_mbox = src_gen[i].src_pkt_mbox;
	   //src_stim[i].exp_pkt_mbox = sb.act_src_mbox;
	   src_mon[i].act_src_mbox = sb.act_src_mbox;
	   dst_mon[i].act_dst_mbox = sb.act_dst_mboxs[i];
	end 
   endfunction:connect
   
   virtual task run();
    foreach(src_stim[i]) begin
	 automatic int id=i;
 	 fork
	   src_stim[id].run();
	   dst_mon[id].run(); 	
	   src_mon[id].run(); 	
	 join_none
    end
	fork
	   sb.run();
	join_none
	reset();
	// fork 
	 // begin 
	  foreach(src_gen[i])begin
	   automatic int id=i;
	   fork
         src_gen[id].run();
	   join_none
	  end 
	  //wait fork;
	 // end
	// join
	test_done_timers();	
   endtask:run

   virtual function void do_config();
     foreach(chnl_cfg[i])begin
	    chnl_cfg[i].sa = i;
		chnl_cfg[i].pkt_num = 0;
	 end
   endfunction:do_config
   
  task reset();
    #205ns;
    rtr_io.reset_n = 1'b0;
    rtr_io.cb.frame_n <= '1;
    rtr_io.cb.valid_n <= '1;
    #405ns;
    rtr_io.reset_n <= 1'b1;
    repeat(15) @(rtr_io.cb);
  endtask: reset
  

  virtual task test_done_timers();
    #1ns;
	test_stop_keys.get(CHNL_NUM);
	repeat(TEST_DONE_DRAIN_TIME) @(rtr_io.cb);
	//#(TEST_DONE_DRAIN_TIME);  time is not enough;
	
	$display("%s finished at %0t",name,$time);
	report();
	$finish;
  endtask:test_done_timers
  
  virtual function void report();
    sb.report();
	$display("========================TEST REPORT===============================");
	if(sb.test_pass_flag)
	   $display("%s is PASSED!",name);
	else
	   $display("%s is FAILED!",name);
	$display("==================================================================");
  endfunction:report   
   

   
endclass:base_test


/**********************************************************************************
*                     6-4 *20    test                                             *
*                                                                                 */
class single_channel_directed_da_test extends base_test;
  
  function new(virtual router_io.TB rtr_io);
    super.new(rtr_io);
	this.name = "single_channel_directed_da_test";
  endfunction:new
  
  
  virtual function void do_config();
    super.do_config();//继承父类
	void'(std::randomize(chnl_da) with {unique {chnl_da};});
    foreach(chnl_cfg[i])begin
	 chnl_cfg[i].da=chnl_da[i];
	 chnl_cfg[i].pkt_num=20;
	end
  endfunction:do_config   
 
endclass: single_channel_directed_da_test


/**********************************************************************************
*               3-9 *20      4-4 *20    test                                      *
*                                                                                 */
class dual_channel_directed_da_test extends base_test;
  
  function new(virtual router_io.TB rtr_io);
    super.new(rtr_io);
	this.name = "dual_channel_directed_da_test";
  endfunction:new
  
  
  virtual function void do_config();

    super.do_config();//继承父类
    chnl_cfg[4].da=4;
	chnl_cfg[4].pkt_num=20;
    chnl_cfg[3].da=9;
	chnl_cfg[3].pkt_num=20;
  endfunction:do_config   
 
endclass: dual_channel_directed_da_test


/**********************************************************************************
*               3-rand *20      4-rand *20    test                                      *
*                                                                                 */
class dual_channel_random_da_test extends base_test;

  function new(virtual router_io.TB rtr_io);
    super.new(rtr_io);
	this.name = "dual_channel_random_da_test";
  endfunction:new
  
  virtual function void do_config();
    super.do_config();//继承父类
	void'(std::randomize(chnl_da) with {unique {chnl_da};});
    chnl_cfg[4].da=chnl_da[0];
	chnl_cfg[4].pkt_num=20;
    chnl_cfg[3].da=chnl_da[1];
	chnl_cfg[3].pkt_num=20;
  endfunction:do_config   
 
endclass: dual_channel_random_da_test

 
/**********************************************************************************
*                        all channel    test                                      *
*                                                                                 */
class all_channel_random_da_test extends base_test;

  function new(virtual router_io.TB rtr_io);
    super.new(rtr_io);
	this.name = "all_channel_random_da_test";
  endfunction:new
  
  
  virtual function void do_config();
    super.do_config();//继承父类
	void'(std::randomize(chnl_da) with {unique {chnl_da};});
    foreach(chnl_cfg[i])begin
	 chnl_cfg[i].da=chnl_da[i];
	 chnl_cfg[i].pkt_num=20;
	end

  endfunction:do_config   
 
endclass: all_channel_random_da_test

endpackage:router_packet

