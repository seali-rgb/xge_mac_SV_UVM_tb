//////////////////////////////////////////////////////////////////////
//                                                                  //
//  File name : packet_tx_driver.sv                                 //
//  Author    : Jiale Wei		                                    //
//  Course    : Advanced Verification Methodology (EE8350)			//
//                                                                  //
//////////////////////////////////////////////////////////////////////
`ifndef PACKET_TX_DRIVER__SV
`define PACKET_TX_DRIVER__SV


class packet_tx_driver extends uvm_driver #(packet);

  //Register with factory
  `uvm_component_utils( packet_tx_driver )
  virtual xge_mac_interface     drv_vi;

  function new(string name="packet_tx_driver", uvm_component parent);
    super.new(name, parent);
  endfunction : new


  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    //Get the interface from config database
    `uvm_info("packet_tx_driver", "build_phase is called", UVM_HIGH)
    if(!uvm_config_db#(virtual xge_mac_interface)::get(this, "", "drv_vi", drv_vi)) begin
		`uvm_error("packet_tx_driver", "Virtual Interface for driver not set!")
    end

  endfunction : build_phase


  virtual task run_phase(uvm_phase phase);
    int unsigned    pkt_len_in_bytes;
    int unsigned    num_of_flits;
    bit [2:0]       last_flit_mod;
    bit [63:0]      tx_data;
	
    `uvm_info( get_name(), $sformatf("HIERARCHY: %m"), UVM_HIGH)

    forever begin
      //Get the request sequence from seq_item_port
      seq_item_port.get_next_item( req );
      if ( req == null ) begin
        // Send random idle
        @(drv_vi.drv_cb);
        drv_vi.drv_cb.pkt_tx_val    <= 1'b0; //Receive Unvalid
        drv_vi.drv_cb.pkt_tx_sop    <= $urandom_range(1,0);
        drv_vi.drv_cb.pkt_tx_eop    <= $urandom_range(1,0);
        drv_vi.drv_cb.pkt_tx_mod    <= $urandom_range(7,0);
        drv_vi.drv_cb.pkt_tx_data   <= { $urandom, $urandom_range(65535,0) };
      end//end-if
      else begin
		//Send data 
        `uvm_info( get_name(), $psprintf("Packet: \n%0s", req.sprint()), UVM_HIGH)
        pkt_len_in_bytes    = 6 + 6 + 2 + req.payload.size(); 
        num_of_flits        = ( pkt_len_in_bytes%8 ) ? pkt_len_in_bytes/8 + 1 : pkt_len_in_bytes/8;
        last_flit_mod       = pkt_len_in_bytes%8;
        `uvm_info( get_name(), $psprintf("pkt_len_in_bytes=%0d, num_of_flits=%0d, last_flit_mod=%0d",
                                pkt_len_in_bytes, num_of_flits, last_flit_mod), UVM_HIGH)
        for ( int i=0; i<num_of_flits; i++ ) begin
          tx_data = 64'h0;
          @(drv_vi.drv_cb);
          if ( i==0 )  begin    // -------------------------------- SOP cycle ----------------
            tx_data = { req.mac_dst_addr, req.mac_src_addr[47:32] };
            drv_vi.drv_cb.pkt_tx_val  <= 1'b1;
            drv_vi.drv_cb.pkt_tx_sop  <= req.sop_mark;
            drv_vi.drv_cb.pkt_tx_eop  <= 1'b0;
            drv_vi.drv_cb.pkt_tx_mod  <= $urandom_range(7,0);
            drv_vi.drv_cb.pkt_tx_data <= tx_data;
          end                   // -------------------------------- SOP cycle ----------------
          else if ( i==(num_of_flits-1) ) begin // ---------------- EOP cycle ----------------
            if ( num_of_flits==2 ) begin
              tx_data[63:16] = { req.mac_src_addr[31:0], req.ether_type };
              tx_data[15:0]  = $urandom_range(16'hFFFF,0);
              for ( int j=0; j<req.payload.size(); j++ ) begin
                if ( j==0 ) begin
                  tx_data[15:8] = req.payload[0];
                end
                else begin
                  tx_data[7:0]  = req.payload[1];
                end
              end
            end
            else begin
              for ( int j=0; j<8; j++ ) begin
                if (j<(((req.payload.size()-3)%8)+1)) begin
                  tx_data = tx_data | ( req.payload[8*i+j-14] << (56-8*j) );
                end
                else begin
                  tx_data = tx_data | ( $urandom_range(8'hFF,0) << (56-8*j) );
                end
              end
            end
            drv_vi.drv_cb.pkt_tx_val  <= 1'b1;
            drv_vi.drv_cb.pkt_tx_sop  <= 1'b0;
            drv_vi.drv_cb.pkt_tx_eop  <= req.eop_mark;
            drv_vi.drv_cb.pkt_tx_mod  <= last_flit_mod;
            drv_vi.drv_cb.pkt_tx_data <= tx_data;
          end                   // -------------------------------- EOP cycle ----------------
          else begin            // -------------------------------- MOP cycle ----------------
            if ( i==1 ) begin
              tx_data = { req.mac_src_addr[31:0], req.ether_type, req.payload[0], req.payload[1] };
            end
            else begin
              for ( int j=0; j<8; j++ ) begin
                tx_data = (tx_data<<8) | req.payload[8*i+j-14];
              end
            end
            drv_vi.drv_cb.pkt_tx_val  <= 1'b1;
            drv_vi.drv_cb.pkt_tx_sop  <= 1'b0;
            drv_vi.drv_cb.pkt_tx_eop  <= 1'b0;
            drv_vi.drv_cb.pkt_tx_mod  <= $urandom_range(0,7);
            drv_vi.drv_cb.pkt_tx_data <= tx_data;
          end                   // -------------------------------- MOP cycle ----------------
        end //for-loop
        repeat ( req.ipg ) begin
          @(drv_vi.drv_cb);
          drv_vi.drv_cb.pkt_tx_val    <= 1'b0;
          drv_vi.drv_cb.pkt_tx_sop    <= $urandom_range(1,0);
          drv_vi.drv_cb.pkt_tx_eop    <= $urandom_range(1,0);
          drv_vi.drv_cb.pkt_tx_mod    <= $urandom_range(7,0);
          drv_vi.drv_cb.pkt_tx_data   <= { $urandom, $urandom_range(65535,0) };
        end //end-preat
        while ( drv_vi.drv_cb.pkt_tx_full ) begin
          // When the pkt_tx_full signal is asserted, transfers should
          // be suspended at the end of the current packet.  Transfer of
          // next packet can begin as soon as this signal is de-asserted.
          @(drv_vi.drv_cb);
          drv_vi.drv_cb.pkt_tx_val    <= 1'b0;
          drv_vi.drv_cb.pkt_tx_sop    <= $urandom_range(1,0);
          drv_vi.drv_cb.pkt_tx_eop    <= $urandom_range(1,0);
          drv_vi.drv_cb.pkt_tx_mod    <= $urandom_range(7,0);
          drv_vi.drv_cb.pkt_tx_data   <= { $urandom, $urandom_range(65535,0) };
        end //end-while
      end//end else
	// Communicate item done to the sequencer
	`uvm_info(get_name(), "This Item is done!", UVM_HIGH)
        seq_item_port.item_done();
    end

  endtask : run_phase

endclass : packet_tx_driver

`endif  // PACKET_TX_DRIVER__SV
