`ifndef INC_DRIVERBASE_SV
`define INC_DRIVERBASE_SV
class DriverBase;
  virtual router_io.TB rtr_io;	// interface signal
  string    name;		// unique identifier
  bit[3:0]  sa, da;		// source and destination addresses
  logic[7:0]  payload[$];		// Packet payload
  Packet    pkt2send;		// stimulus Packet object

  extern function new(string name = "DriverBase", virtual router_io.TB rtr_io);
  extern virtual task send();
  extern virtual task send_addrs();
  extern virtual task send_pad();
  extern virtual task send_payload();
endclass

function DriverBase::new(string name, virtual router_io.TB rtr_io);
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, name);
  this.name   = name;
  this.rtr_io = rtr_io;
endfunction

task DriverBase::send();
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, name);
  send_addrs();
  send_pad();
  send_payload();
endtask

task DriverBase::send_addrs();
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, name);
  rtr_io.cb.frame_n[sa] <= 1'b0;
  for(int i=0; i<4; i++) begin
    rtr_io.cb.din[sa] <= da[i];
    @(rtr_io.cb);
  end
endtask

task DriverBase::send_pad();
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, name);
  rtr_io.cb.din[sa] <= 1'b1;
  rtr_io.cb.valid_n[sa] <= 1'b1;
  repeat(5) @(rtr_io.cb);
endtask

task DriverBase::send_payload();
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, name);
  foreach(payload[index]) begin
    for(int i=0; i<8; i++) begin
      rtr_io.cb.din[sa] <= payload[index][i];
      rtr_io.cb.valid_n[sa] <= 1'b0;
      rtr_io.cb.frame_n[sa] <= ((index == (payload.size() - 1)) && (i == 7));
      @(rtr_io.cb);
    end
  end
  rtr_io.cb.valid_n[sa] <= 1'b1;
endtask
`endif
