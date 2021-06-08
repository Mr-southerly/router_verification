interface router_io(input bit clock);
  logic		reset_n;
  logic [15:0]	din;
  logic [15:0]	frame_n;
  logic [15:0]	valid_n;
  logic [15:0]	dout;
  logic [15:0]	valido_n;
  logic [15:0]	busy_n;
  logic [15:0]	frameo_n;

  clocking cb @(posedge clock);
    default input #1 output #1;
    inout reset_n;
    inout din;
    inout frame_n;
    inout valid_n;
    input dout;
    input valido_n;
    input busy_n;
    input frameo_n;
  endclocking

  modport TB(clocking cb, output reset_n);
  

  parameter int CHNL_NUM = 16;

  typedef enum bit[2:0] {IDLE_STATE, ADDRESS_STATE, PAD_STATE, PAYLOAD_STATE} chnl_state_t;
  class packet;
    logic[3:0] sa;
    logic[3:0] da;
    logic[7:0] payload[];
  endclass

  chnl_state_t [CHNL_NUM-1:0] chnls_state;

  // check if all channles would coordiate together
  covergroup all_channels_work_cg @(posedge clock);
    option.name = "all_channels_work_cg";
    FRAME_N: coverpoint frame_n {
      bins all_frame_n = {16'h0};
    }
    VALID_N: coverpoint valid_n {
      bins all_valid_n = {16'h0};
    }
    FRAME_X_VALID: cross FRAME_N, VALID_N; 
    FRAMEO_N: coverpoint frameo_n {
      bins all_frameo_n = {16'h0};
    }
    VALIDO_N: coverpoint valido_n {
      bins all_valido_n = {16'h0};
    }
    FRAMEO_X_VALIDO: cross FRAMEO_N, VALIDO_N;
  endgroup

  // check at least any channles work with another channel in dual
  covergroup dual_channels_work_cg(input int cid1, input cid2) @(chnls_state[cid1], chnls_state[cid2]);
    option.name = $sformatf("dual_channels_ch%0d_x_ch%0d_cg", cid1, cid2);
    option.per_instance = 1;
    type_option.merge_instances = 0;
    SINGLE_CHNL_STATE1: coverpoint chnls_state[cid1] {
      bins idle_state = {IDLE_STATE};
      bins address_state = {ADDRESS_STATE};
      bins pad_state = {PAD_STATE};
      bins payload_state = {PAYLOAD_STATE};
    }
    SINGLE_CHNL_STATE2: coverpoint chnls_state[cid2] {
      bins idle_state = {IDLE_STATE};
      bins address_state = {ADDRESS_STATE};
      bins pad_state = {PAD_STATE};
      bins payload_state = {PAYLOAD_STATE};
    }
    PARA_CHNLS_STATE: cross SINGLE_CHNL_STATE1, SINGLE_CHNL_STATE2; 
  endgroup

  // sample event is not specified but manually called via sample() method
  covergroup single_channel_work_cg(input int id) with function sample(input packet pkt);
    option.name = $sformatf("single_channel_work_cg[%0d]", id);
    option.per_instance = 1;
    type_option.merge_instances = 0;
    DA: coverpoint pkt.da;
    PL_SIZE: coverpoint pkt.payload.size() {
      bins psize[] = {[2:4]};
    }
  endgroup

  all_channels_work_cg all_channels_cg;
  dual_channels_work_cg dual_channels_cgs[CHNL_NUM/2];
  single_channel_work_cg single_channel_cgs[CHNL_NUM];

  initial begin
    // covergroup instances
    all_channels_cg = new();
    foreach(single_channel_cgs[i])  single_channel_cgs[i] = new(i);
    foreach(dual_channels_cgs[i]) dual_channels_cgs[i] = new(i*2, (i*2)+1);
    // monitor packets and sample coverage
    channels_monitor_packets();
  end

  task automatic channels_monitor_packets();
    // monitor CHNL_NUM single channles
    for(int i = 0; i < CHNL_NUM; i++) begin
      automatic int id = i;
      fork
        monitor_packet(id);
      join_none
    end
    // monitor all dual channels
  endtask


  task automatic monitor_packet(input int id);
    packet pkt;
    forever begin
      pkt = new();
      pkt.sa = id;
      mon_addrs(pkt);
      mon_pad(pkt);
      mon_payload(pkt);
      // sample packet coverage once the packet finished
      single_channel_cgs[id].sample(pkt);
    end
  endtask

  task automatic mon_addrs(input packet pkt);
    @(negedge frame_n[pkt.sa]) chnls_state[pkt.sa] = ADDRESS_STATE;
	  for(int i = 0; i<4; i++) begin
      @(negedge clock); // ensure correct data sampling
      pkt.da[i] <= din[pkt.sa];
	  end
  endtask

  task automatic mon_pad(input packet pkt);
    @(posedge clock) chnls_state[pkt.sa] = PAD_STATE;
    repeat(5) @(negedge clock);
    @(posedge clock) chnls_state[pkt.sa] = PAYLOAD_STATE;
  endtask

  task automatic mon_payload(input packet pkt);
    int pl_count = 0;
    forever begin
      pl_count ++;
      pkt.payload = new[pl_count](pkt.payload); // enlarge and copy items
	    for(int i=0; i<8; i++) begin
        @(negedge clock); 
        if(valido_n[pkt.sa] === 0) begin // available for interleaved valid_n = {0, 1}
          pkt.payload[pl_count-1][i] = din[pkt.sa];
          if(frame_n[pkt.sa] === 1) begin
            @(posedge clock) chnls_state[pkt.sa] = IDLE_STATE;
            return; // last data in frame
          end
        end
      end
    end
  endtask
endinterface: router_io
