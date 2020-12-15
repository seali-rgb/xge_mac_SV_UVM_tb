//////////////////////////////////////////////////////////////////////
//                                                                  //
//  File name : wishbone_driver.sv                                  //
//  Author    : Jiale Wei					    //
//  Course    : EE8350 Advanced Verification Methodology 	    //
//                                                                  //
//////////////////////////////////////////////////////////////////////
`ifndef WISHBONE_DRIVER__SV
`define WISHBONE_DRIVER__SV

`include "wishbone_item.sv"
class wishbone_driver extends uvm_driver #(wishbone_item);
  //Declare vritual interface 
  virtual xge_mac_interface     drv_vi;
  //Register in factory
  `uvm_component_utils( wishbone_driver )

  function new(string name="wishbone_driver", uvm_component parent);
    super.new(name, parent);
  endfunction : new


  virtual function void build_phase( uvm_phase phase);
    super.build_phase(phase);
    //Get the virtual interface from uvm_config_db
    uvm_config_db#(virtual xge_mac_interface)::get(this, "", "drv_vi", drv_vi);
    if ( drv_vi==null )
      `uvm_fatal(get_name(), "Virtual Interface for driver not set!");
  endfunction : build_phase


  virtual task run_phase( uvm_phase phase);
    `uvm_info( get_name(), $sformatf("HIERARCHY: %m"), UVM_HIGH);
    forever begin
      seq_item_port.get_next_item(req);
      if ( req == null ) begin
        // Send random idle
        @(drv_vi.drv_cb);
        drv_vi.drv_cb.wb_adr_i  <= $urandom_range(255,0);
        drv_vi.drv_cb.wb_cyc_i  <= 1'b0;
        drv_vi.drv_cb.wb_stb_i  <= 1'b0;
        drv_vi.drv_cb.wb_dat_i  <= $urandom;
        drv_vi.drv_cb.wb_we_i   <= 1'b0;
      end
      else begin
        `uvm_info( get_name(), $psprintf("Wishbone Transaction: \n%0s", req.sprint()), UVM_HIGH)
        @(drv_vi.drv_cb);
        drv_vi.drv_cb.wb_adr_i  <= req.xtxn_addr;
        drv_vi.drv_cb.wb_cyc_i  <= 1'b1;
        drv_vi.drv_cb.wb_stb_i  <= 1'b1;
        drv_vi.drv_cb.wb_dat_i  <= req.xtxn_data;
        drv_vi.drv_cb.wb_we_i   <= req.xtxn_n;
        repeat (2)
          @(drv_vi.drv_cb);
        repeat (20) begin
          drv_vi.drv_cb.wb_adr_i  <= $urandom_range(255,0);
          drv_vi.drv_cb.wb_cyc_i  <= 1'b0;
          drv_vi.drv_cb.wb_stb_i  <= 1'b0;
          drv_vi.drv_cb.wb_dat_i  <= $urandom;
          drv_vi.drv_cb.wb_we_i   <= 1'b0;
          @(drv_vi.drv_cb);
        end
        seq_item_port.item_done();
      end
    end
  endtask : run_phase

endclass : wishbone_driver

`endif  // WISHBONE_DRIVER__SV
