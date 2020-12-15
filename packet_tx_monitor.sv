//////////////////////////////////////////////////////////////////////
//                                                                  //
//  File name : packet_tx_monitor.sv                                //
//  Author    : Jiale Wei		                            //
//  Course    : Advanced Verification Methodology (EE8350)	    //
//                                                                  //
//////////////////////////////////////////////////////////////////////
`ifndef PACKET_TX_MONITOR__SV
`define PACKET_TX_MONITOR__SV


class packet_tx_monitor extends uvm_monitor;
  `uvm_component_utils( packet_tx_monitor )
  //Declare the virtual interface
  virtual xge_mac_interface     mon_vi;
  int unsigned                  m_num_captured;
  uvm_analysis_port #(packet)   tx_Mon2Sb_port;
  //uvm_analysis_port #(packet) sub_port_from_tx_mon;

  

  function new( string name="packet_tx_monitor",  uvm_component parent);
    super.new(name, parent);
  endfunction : new


  virtual function void build_phase( uvm_phase phase);
    super.build_phase(phase);
    m_num_captured = 0;
    //from_pkt_tx_agent = new ( "from_pkt_tx_agent", this );
    //Instantiate Monitor analysis port
    tx_Mon2Sb_port = new("tx_Mon2Sb_port", this);
    //sub_port_from_tx_mon = new("sub_port_from_tx_mon", this);
    //Get the interface reference from config database
    if(!uvm_config_db#(virtual xge_mac_interface)::get(this, "", "mon_vi", mon_vi))
      `uvm_fatal("packet_tx_monitor", "Virtual Interface for monitor not set!");
  endfunction : build_phase


  virtual task run_phase( uvm_phase phase);
    packet      rcv_pkt;
    bit         pkt_in_progress = 0;
    bit [7:0]   rx_data_q[$];
    int         idx;
    bit         packet_captured = 0;

    `uvm_info( get_name(), $sformatf("HIERARCHY: %m"), UVM_HIGH);

    forever begin
      @(mon_vi.mon_cb)
      if ( mon_vi.mon_cb.pkt_tx_val ) begin
        if ( mon_vi.mon_cb.pkt_tx_sop && !mon_vi.mon_cb.pkt_tx_eop && pkt_in_progress==0 ) begin
          // -------------------------------- SOP cycle ----------------
          rcv_pkt = packet::type_id::create("rcv_pkt");
	  //rcv_pkt = packet::type_id::create("rcv_pkt", this);
          pkt_in_progress = 1;
          rcv_pkt.sop_mark            = mon_vi.mon_cb.pkt_tx_sop;
          rcv_pkt.mac_dst_addr        = mon_vi.mon_cb.pkt_tx_data[63:16];
          rcv_pkt.mac_src_addr[47:32] = mon_vi.mon_cb.pkt_tx_data[15:0];
          rcv_pkt.mac_src_addr[31:0]  = 32'h0;
          rcv_pkt.ether_type          = 16'h0;
          rcv_pkt.payload = new[0];
          while ( rx_data_q.size()>0 ) begin
            rx_data_q.pop_front();
          end
        end   // ---------------------------- SOP cycle ----------------
        if ( !mon_vi.mon_cb.pkt_tx_sop && !mon_vi.mon_cb.pkt_tx_eop && pkt_in_progress==1 ) begin
          // -------------------------------- MOP cycle ----------------
          pkt_in_progress = 1;
          if ( rx_data_q.size()==0 ) begin
            rcv_pkt.mac_src_addr[31:0]  = mon_vi.mon_cb.pkt_tx_data[63:32];
            rcv_pkt.ether_type          = mon_vi.mon_cb.pkt_tx_data[31:16];
            rx_data_q.push_back(mon_vi.mon_cb.pkt_tx_data[15:8]);
            rx_data_q.push_back(mon_vi.mon_cb.pkt_tx_data[7:0]);
          end
          else begin
            for ( int i=0; i<8; i++ ) begin
              rx_data_q.push_back( (mon_vi.mon_cb.pkt_tx_data >> (64-8*(i+1))) & 8'hFF );
            end
          end
        end   // ---------------------------- MOP cycle ----------------
        if ( mon_vi.mon_cb.pkt_tx_eop && pkt_in_progress==1 ) begin
          // -------------------------------- EOP cycle ----------------
          rcv_pkt.eop_mark= mon_vi.mon_cb.pkt_tx_eop;
          pkt_in_progress = 0;
          if ( rx_data_q.size()==0 ) begin
            rcv_pkt.mac_src_addr[31:0]  = mon_vi.mon_cb.pkt_tx_data[63:32];
            rcv_pkt.ether_type          = mon_vi.mon_cb.pkt_tx_data[31:16];
            if ( mon_vi.mon_cb.pkt_tx_mod==0 ) begin
              rx_data_q.push_back(mon_vi.mon_cb.pkt_tx_data[15:8]);
              rx_data_q.push_back(mon_vi.mon_cb.pkt_tx_data[7:0]);
            end
            else if ( mon_vi.mon_cb.pkt_tx_mod==7 ) begin
              rx_data_q.push_back(mon_vi.mon_cb.pkt_tx_data[15:8]);
            end
          end
          else begin
            if ( mon_vi.mon_cb.pkt_tx_mod==0 ) begin
              for ( int i=0; i<8; i++ ) begin
                rx_data_q.push_back( (mon_vi.mon_cb.pkt_tx_data >> (64-8*(i+1))) & 8'hFF );
              end
            end
            else begin
              for ( int i=0; i<mon_vi.mon_cb.pkt_tx_mod; i++ ) begin
                rx_data_q.push_back( (mon_vi.mon_cb.pkt_tx_data >> (64-8*(i+1))) & 8'hFF );
              end
            end
          end
          rcv_pkt.payload = new[rx_data_q.size()];
          idx = 0;
          while ( rx_data_q.size()>0 ) begin
            rcv_pkt.payload[idx]  = rx_data_q.pop_front();
            idx++;
          end
          packet_captured  = 1;
        end   // -------------------------------- EOP cycle ----------------
        if ( packet_captured ) begin
	  //Print the received packet
          `uvm_info( get_name(), $psprintf("Packet: \n%0s", rcv_pkt.sprint()), UVM_HIGH)
          if ( rcv_pkt.sop_mark && rcv_pkt.eop_mark ) begin
	  //Send the transaction to scoreboard
	  tx_Mon2Sb_port.write(rcv_pkt);
	  //Send the transaction to subscriber
	  //sub_port_from_tx_mon.write(rcv_pkt);
            m_num_captured++;
          end
          packet_captured = 0;
        end
      end
    end
  endtask : run_phase


  function void report_phase( uvm_phase phase );
    `uvm_info( get_name( ), $sformatf( "REPORT: Captured %0d packets", m_num_captured ), UVM_LOW )
  endfunction : report_phase

endclass : packet_tx_monitor

`endif  //PACKET_TX_MONITOR__SV
