# ###########################################################
# ██████  ███    ███ ███████     ███    ███ ██ ████████ 
# ██   ██ ████  ████ ██          ████  ████ ██    ██    
# ██████  ██ ████ ██ █████       ██ ████ ██ ██    ██    
# ██   ██ ██  ██  ██ ██          ██  ██  ██ ██    ██    
# ██████  ██      ██ ███████     ██      ██ ██    ██    
# 2023-2024, Jozsef Mozer
# ###########################################################

# Create the Tanimoto dissimilarity calculator IP project for the ZCU106 evaluation board.
create_project tanimoto_rtl ./tanimoto_rtl -part xczu7ev-ffvc1156-2-e
set_property board_part xilinx.com:zcu106:part0:2.6 [current_project]

# Create the top level block of the IP.
create_bd_design "tanimoto"
add_files -fileset sources_1 [glob ./tanimoto_rtl/verilog/sources_1/*.v]
update_compile_order -fileset sources_1
startgroup
create_bd_cell -type module -reference top_intf -name top_intf_0
endgroup
startgroup
make_bd_pins_external [get_bd_pins top_intf_0/ap_clk]
make_bd_pins_external [get_bd_pins top_intf_0/ap_rstn]
make_bd_intf_pins_external  [get_bd_intf_pins top_intf_0/S_AXIS_DATA] [get_bd_intf_pins top_intf_0/M_AXIS_ID_PAIR]
make_bd_pins_external [get_bd_pins top_intf_0/ap_threshold]
endgroup

set_property name S_AXIS_DATA [get_bd_intf_ports S_AXIS_DATA_0]
set_property name M_AXIS_ID_PAIR [get_bd_intf_ports M_AXIS_ID_PAIR_0]
set_property name ap_clk [get_bd_ports ap_clk_0]

set_property CONFIG.ASSOCIATED_BUSIF S_AXIS_DATA:M_AXIS_ID_PAIR [get_bd_pins /top_intf_0/ap_clk]

# Create HDL wrapper.
make_wrapper -files [get_files {./tanimoto_rtl/tanimoto_rtl.srcs/sources_1/bd/tanimoto/tanimoto.bd}] -top
add_files -norecurse ./tanimoto_rtl/tanimoto_rtl.gen/sources_1/bd/tanimoto/hdl/tanimoto_wrapper.v


# Package and export IP.
ipx::package_project -root_dir ./tanimoto_ip -vendor mit.bme.hu -library tanimoto -taxonomy /UserIP -import_files -set_current false
ipx::unload_core ./tanimoto_ip/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory ./tanimoto_ip ./tanimoto_ip/component.xml
update_compile_order -fileset sources_1
ipx::associate_bus_interfaces -busif S_AXIS_DATA -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif M_AXIS_ID_PAIR -clock ap_clk [ipx::current_core]
set_property xpm_libraries {XPM_CDC XPM_MEMORY XPM_FIFO} [ipx::current_core]
set_property sdx_kernel true [ipx::current_core]
set_property sdx_kernel_type rtl [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::check_integrity -quiet [ipx::current_core]
ipx::archive_core ./tanimoto_ip/tanimoto_ip_0.1.zip [ipx::current_core]


close_project -delete
