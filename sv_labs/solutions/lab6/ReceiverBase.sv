`ifndef INC_RECEIVERBASE_SV
`define INC_RECEIVERBASE_SV
class ReceiverBase;
  virtual router_io.TB rtr_io;	// interface signals
  string   name;		// unique identifier
  bit[3:0] da;			// output port to monitor
  logic[7:0] pkt2cmp_payload[$];	// actual payload array
  Packet   pkt2cmp;		// actual Packet object

  extern function new(string name = "ReceiverBase", virtual router_io.TB rtr_io);
  extern virtual task recv();
  extern virtual task get_payload();
endclass

function ReceiverBase::new(string name, virtual router_io.TB rtr_io);
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, name);
  this.name = name;
  this.rtr_io = rtr_io;
  pkt2cmp = new();
endfunction

task ReceiverBase::recv();
  static int pkt_cnt = 0;
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, name);
  get_payload();
  pkt2cmp.da = da;
  pkt2cmp.payload = pkt2cmp_payload;
  pkt2cmp.name = $psprintf("rcvdPkt[%0d]", pkt_cnt++);
endtask

task ReceiverBase::get_payload();
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, name);
  pkt2cmp_payload.delete();
  fork
    begin: wd_timer_fork
    fork: frameo_wd_timer
      @(negedge rtr_io.cb.frameo_n[da]);
      begin
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
    for (int i=0; i<8; ) begin
      if (!rtr_io.cb.valido_n[da])
        datum[i++] = rtr_io.cb.dout[da];
      if (rtr_io.cb.frameo_n[da])
        if (i == 8) begin
          pkt2cmp_payload.push_back(datum);
          return;
        end
        else begin
          $display("\n%m\n[ERROR]%t Packet payload not byte aligned!\n", $realtime);
          $finish;
        end
      @(rtr_io.cb);
    end
    pkt2cmp_payload.push_back(datum);
  end
endtask
`endif
