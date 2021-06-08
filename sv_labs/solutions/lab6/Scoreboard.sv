`ifndef INC_SCOREBOARD_SV
`define INC_SCOREBOARD_SV
class Scoreboard;
  string   name;		// unique identifier
  event    DONE;		// flag to indicate goal reached
  Packet   refPkt[$];		// reference Packet array
  Packet   pkt2send;		// Packet object from Drivers
  Packet   pkt2cmp;		// Packet object from Receivers
  pkt_mbox  driver_mbox;		// mailbox for Packet objects from Drivers
  pkt_mbox  receiver_mbox;	// mailbox for Packet objects from Receivers

  //Lab6 Task 2 Step 2
  //Define two new 4-bit class properties sa, da
  //ToDo
  bit[3:0] sa, da;


  //Lab6 Task 2 Steps 3,4
  //Define a covergroup router_cov
  //Inside the covergroup define coverpoints for sa and da
  //Inside the covergroup define a cross of the coverpoints for sa and da
  //ToDo
  covergroup router_cov;
    coverpoint sa;
    coverpoint da;
	cross sa, da;
  endgroup: router_cov


  extern function new(string name = "Scoreboard", pkt_mbox driver_mbox = null, receiver_mbox = null);
  extern virtual task start();
  extern virtual task check();
endclass: Scoreboard

function Scoreboard::new(string name, pkt_mbox driver_mbox, receiver_mbox);
  if (TRACE_ON) $display("[TRACE]%0t %s:%m", $time, name);
  this.name = name;
  if (driver_mbox == null) driver_mbox = new();
  this.driver_mbox = driver_mbox;
  if (receiver_mbox == null) receiver_mbox = new();
  this.receiver_mbox = receiver_mbox;


  //Lab6 Task 3 Step 1
  //Construct the covergroup router_cov
  //Note the instance name is same as covergroup name
  //ToDo
  router_cov = new();

endfunction: new

task Scoreboard::start();
  if (TRACE_ON) $display("[TRACE]%0t %s:%m", $time, name);
  fork
    while (1) begin
      this.receiver_mbox.get(this.pkt2cmp);
      while (this.driver_mbox.num()) begin
        Packet pkt;
        this.driver_mbox.get(pkt);
        this.refPkt.push_back(pkt);
      end
      this.check();
    end
  join_none
endtask: start

task Scoreboard::check();
  int    index[$];
  string message;
  static int  pkts_checked = 0;


  //Lab6 Task 4 Step 1
  //Define a real variable coverage_result to store coverage numbers
  //ToDo
  real coverage_result;

  if (TRACE_ON) $display("[TRACE]%0t %s:%m", $time, name);
  index = this.refPkt.find_first_index() with (item.da == this.pkt2cmp.da);
  if (index.size() <= 0) begin
    $display("\n%m\n[ERROR]%0t %s not found in Reference Queue\n", $time, this.pkt2cmp.name);
    this.pkt2cmp.display("ERROR");
    $finish;
  end
  this.pkt2send = this.refPkt[index[0]];
  this.refPkt.delete(index[0]);
  if (!this.pkt2send.compare(this.pkt2cmp, message)) begin
    $display("\n%m\n[ERROR]%0t Packet #%0d %s\n", $time, pkts_checked, message);
    this.pkt2send.display("ERROR");
    this.pkt2cmp.display("ERROR");
    $finish;
  end


  //Lab6 Task 4 Step 2
  //Set the class sa and da variables to match the ones in pkt2send
  //ToDo
  this.sa = pkt2send.sa;
  this.da = pkt2send.da;


  //Lab6 Task 4 Step 3
  //Update the covergroup bins with sample()
  //ToDo
  this.router_cov.sample();


  //Lab6 Task 4 Step 4
  //update the coverage_result value with a call to $get_coverage()
  //ToDo
  coverage_result = $get_coverage();


  //Lab6 Task 4 Step 5
  //Add coverage value to display statement
  //ToDo
  $display("[NOTE]%0t Packet #%0d %s - Coverage = %3.2f", $time, pkts_checked++, message, coverage_result);


  //Lab6 Task 4 Step 6
  //Modify if to add check for 100% coverage
  //ToDo
  if ((pkts_checked >= run_for_n_packets) || (coverage_result == 100.00))
    ->this.DONE;
endtask: check
`endif
