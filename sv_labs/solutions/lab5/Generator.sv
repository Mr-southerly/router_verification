`ifndef INC_GENERATOR_SV
`define INC_GENERATOR_SV
class Generator;
  string  name;		// unique identifier
  Packet  pkt2send;	// stimulus Packet object
  pkt_mbox out_box[];	// mailbox to Drivers

  extern function new(string name = "Generator");
  extern virtual task gen();
  extern virtual task start();
endclass: Generator

function Generator::new(string name);
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, name);
  this.name = name;
  this.pkt2send = new();
  this.out_box = new[16];
  foreach(this.out_box[i])
    this.out_box[i] = new();
endfunction: new

task Generator::gen();
  static int pkts_generated = 0;
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, this.name);
  this.pkt2send.name = $psprintf("Packet[%0d]", pkts_generated++);
  if (!this.pkt2send.randomize()) begin
    $display("\n%m\n[ERROR]%t Randomization Failed!\n", $realtime);
    $finish;
  end
endtask: gen

task Generator::start();
  if (TRACE_ON) $display("[TRACE]%t %s:%m", $realtime, this.name);
  fork
    for (int i=0; i<run_for_n_packets || run_for_n_packets <= 0; i++) begin
      this.gen();
      begin
        Packet pkt = new this.pkt2send;
        this.out_box[pkt.sa].put(pkt);
      end
    end
  join_none
endtask: start
`endif
