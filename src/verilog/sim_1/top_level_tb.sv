`timescale 1ns / 1ps

import axi4stream_vip_pkg::*;
import system_axi4stream_vip_0_0_pkg::*;
import system_axi4stream_vip_1_0_pkg::*;

module top_level_tb(
  );

  localparam HLAF_CLK_PERIOD = 10;
  localparam CLK_PERIOD = 2 * HLAF_CLK_PERIOD;
  localparam VECTOR_WIDTH = 920;
  localparam CNT_WIDTH = $clog2(VECTOR_WIDTH);

  // Monitor transaction from master VIP
  axi4stream_monitor_transaction                 mst_monitor_transaction;
  // Monitor transaction queue for master VIP 
  axi4stream_monitor_transaction                 master_monitor_transaction_queue[$];
  // Size of master_monitor_transaction_queue
  xil_axi4stream_uint                            master_monitor_transaction_queue_size =0;
  // Scoreboard transaction from master monitor transaction queue
  axi4stream_monitor_transaction                 mst_scb_transaction;
  // Monitor transaction for slave VIP
  axi4stream_monitor_transaction                 slv_monitor_transaction;
  // Monitor transaction queue for slave VIP
  axi4stream_monitor_transaction                 slave_monitor_transaction_queue[$];
  // Size of slave_monitor_transaction_queue
  xil_axi4stream_uint                            slave_monitor_transaction_queue_size =0;
  // Scoreboard transaction from slave monitor transaction queue
  axi4stream_monitor_transaction                 slv_scb_transaction;
  xil_axi4stream_uint                            mst_agent_verbosity = 0;
  xil_axi4stream_uint                            slv_agent_verbosity = 0;
  system_axi4stream_vip_0_0_mst_t                              mst_agent;
  system_axi4stream_vip_1_0_slv_t                              slv_agent;

  event agents_started_event;
     
  // Clock signal
  bit                                     clock;
  // Reset signal
  bit                                     reset;

  reg [CNT_WIDTH-1:0] threshold = 0;
  reg [CNT_WIDTH-1:0] threshold_addr = 0;
  reg                 wr_threshold = 0;

  // instantiate bd
  system_wrapper DUT(
    .aresetn_0            (reset          ),
    .aclk_0               (clock          ),
    .BRAM_PORTA_addr_a_0  (threshold_addr ),
    .BRAM_PORTA_wrdata_a_0(threshold      ),
    .BRAM_PORTA_en_a_0    (1'b1           ),
    .BRAM_PORTA_we_a_0    (wr_threshold   )
  );

  always #HLAF_CLK_PERIOD clock <= ~clock;

  //Main process
  initial begin

    mst_monitor_transaction = new("mst_monitor_tx");
    slv_monitor_transaction = new("slv_monitor_tx");

    // configure threshold BRAM
    configure_bram();

    // instantiate agents, pass VIP interface handles
    mst_agent = new("master vip agent",DUT.system_i.axi4stream_vip_0.inst.IF);
    slv_agent = new("slave vip agent",DUT.system_i.axi4stream_vip_1.inst.IF);
    $timeformat (-12, 1, " ps", 1);

    // idle bus must be driven to 0
    mst_agent.vif_proxy.set_dummy_drive_type(XIL_AXI4STREAM_VIF_DRIVE_NONE);
    slv_agent.vif_proxy.set_dummy_drive_type(XIL_AXI4STREAM_VIF_DRIVE_NONE);

    // set agent tags for easier debugging
    mst_agent.set_agent_tag("Master VIP");
    slv_agent.set_agent_tag("Slave VIP");
    // set print out verbosity level.
    mst_agent.set_verbosity(mst_agent_verbosity);
    slv_agent.set_verbosity(slv_agent_verbosity);

    // start agents
    mst_agent.start_master();
    slv_agent.start_slave();

    -> agents_started_event;

    reset_dut();

    // generate master transactions on the tanimoto accelerator's input
    // always assert tready on the slave side
    fork
      begin
        mst_gen_transaction();
        $display("Simple master to slave transfer example with randomization completes");
        for(int i = 0; i < 100;i++) begin
          mst_gen_transaction();
        end  
        $display("Test stimulus complete.");
      end
      begin
        slv_gen_tready();
      end
    join_any
  end

  task configure_bram();
    #CLK_PERIOD;
    wr_threshold <= 1;
    for(integer i = 0; i < VECTOR_WIDTH; i = i + 1) begin
        threshold = threshold + 1;
        // threshold = 0;
        threshold_addr = threshold_addr + 1;
        #CLK_PERIOD;
    end
    wr_threshold <= 0;
  endtask: configure_bram
  
  task reset_dut();
    reset <= 0;
    #CLK_PERIOD;
    reset <= 1;
  endtask : reset_dut

  // Generate TREADY in slv VIP
  //  XIL_AXI4STREAM_READY_GEN_OSC - Ready stays low for low_time and then goes to high and stays 
  //                               high for high_time, it then goes to low and repeat the same pattern
  task slv_gen_tready();
    axi4stream_ready_gen ready_gen;
    ready_gen = slv_agent.driver.create_ready("ready_gen");
    ready_gen.set_ready_policy(XIL_AXI4STREAM_READY_GEN_SINGLE);
    ready_gen.set_low_time(2);
    ready_gen.set_high_time(6);
    slv_agent.driver.send_tready(ready_gen);
  endtask :slv_gen_tready

  // mst VIP generate transaction
  task mst_gen_transaction();
    axi4stream_transaction wr_transaction; 
    wr_transaction = mst_agent.driver.create_transaction("mst_vip_transaction");
    // wr_transaction.set_xfer_alignment(XIL_AXI4STREAM_XFER_RANDOM);
    WR_TRANSACTION_FAIL: assert(wr_transaction.randomize());
    mst_agent.driver.send(wr_transaction);
  endtask

  // mst transaction: monitor --> queue
  initial begin
    @(agents_started_event);
    forever begin
      mst_agent.monitor.item_collected_port.get(mst_monitor_transaction);
      master_monitor_transaction_queue.push_back(mst_monitor_transaction);
      master_monitor_transaction_queue_size++;
    end  
  end 

  // slv transaction: monitor --> queue
  initial begin
    @(agents_started_event);
    forever begin
      slv_agent.monitor.item_collected_port.get(slv_monitor_transaction);
      slave_monitor_transaction_queue.push_back(slv_monitor_transaction);
      slave_monitor_transaction_queue_size++;
    end
  end

endmodule
