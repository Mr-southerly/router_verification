`ifndef INC_RECEIVER_SV
`define INC_RECEIVER_SV
`include "ReceiverBase.sv"
class Receiver extends ReceiverBase;
  pkt_mbox out_box;	// Scoreboard mailbox

  extern function new(string name = "Receiver", int port_id, pkt_mbox out_box, virtual router_io.TB rtr_io);
  extern virtual task start();
endclass

function Receiver::new(string name, int port_id, pkt_mbox out_box, virtual router_io.TB rtr_io);
  super.new(name, rtr_io);
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, name);
  this.da = port_id;
  this.out_box = out_box;
endfunction

task Receiver::start();
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, name);
  fork
    forever begin
      recv();
      begin
        Packet pkt = new pkt2cmp;
        out_box.put(pkt);
      end
    end
  join_none
endtask
`endif

// Do not uncomment!
//
// class ReceiverBase;
//   virtual router_io.TB rtr_io;	// interface signals
//   string   name;			// unique identifier
//   bit[3:0] da;			// output port to monitor
//   logic[7:0] pkt2cmp_payload[$];	// actual payload array
//   Packet   pkt2cmp;			// actual Packet object
//
//   extern function new(string name = "ReceiverBase", virtual router_io.TB rtr_io);
//   extern virtual task recv();
//   extern virtual task get_payload();
// endclass
