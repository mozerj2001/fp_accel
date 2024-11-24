# ###########################################################
# ██████  ███    ███ ███████     ███    ███ ██ ████████ 
# ██   ██ ████  ████ ██          ████  ████ ██    ██    
# ██████  ██ ████ ██ █████       ██ ████ ██ ██    ██    
# ██   ██ ██  ██  ██ ██          ██  ██  ██ ██    ██    
# ██████  ██      ██ ███████     ██      ██ ██    ██    
# 2023-2024, Jozsef Mozer
# ###########################################################

set FP_ROOT $env(FP_ROOT)

# This script creates a top level block design with a manager
# and subordinate AXI VIP connected to the in- and output ports
# of the DUT respectively.
create_project top_level_tb ${FP_ROOT}/top_level_tb -part xczu7ev-ffvc1156-2-e
set_property board_part xilinx.com:zcu106:part0:2.6 [current_project]

# Create the top level block of the IP.
create_bd_design "system"
add_files -fileset sources_1 [glob ${FP_ROOT}/src/verilog/sources_1/*.v]
add_files -fileset sim_1 [glob ${FP_ROOT}/src/verilog/sim_1/tb_*.v]
add_files -fileset sim_1 [glob ${FP_ROOT}/src/verilog/sim_1/*.sv]
update_compile_order -fileset sources_1

open_bd_design {${FP_ROOT}/top_level_tb/top_level_tb.srcs/sources_1/bd/top_level_tb/system.bd}

# Create RTL block from source files.
startgroup
create_bd_cell -type module -reference top_intf -name top_intf_0
endgroup

# Add, configure and connect AXI Stream VIPs
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi4stream_vip:1.1 axi4stream_vip_0
create_bd_cell -type ip -vlnv xilinx.com:ip:axi4stream_vip:1.1 axi4stream_vip_1

set_property -dict [list CONFIG.INTERFACE_MODE {MASTER} CONFIG.TDEST_WIDTH {0} CONFIG.TID_WIDTH {0} CONFIG.TDATA_WIDTH {64}] [get_bd_cells axi4stream_vip_0]
set_property -dict [list CONFIG.INTERFACE_MODE {SLAVE} CONFIG.TDEST_WIDTH {0} CONFIG.TID_WIDTH {0} CONFIG.TDATA_WIDTH {2}] [get_bd_cells axi4stream_vip_1]

connect_bd_intf_net [get_bd_intf_pins axi4stream_vip_0/M_AXIS] [get_bd_intf_pins top_intf_0/S_AXIS_DATA]
connect_bd_intf_net [get_bd_intf_pins axi4stream_vip_1/S_AXIS] [get_bd_intf_pins top_intf_0/M_AXIS_ID_PAIR]
endgroup

# Create and connect clock port [aclk_0]
startgroup
make_bd_pins_external  [get_bd_pins axi4stream_vip_0/aclk]
connect_bd_net [get_bd_ports aclk_0] [get_bd_pins top_intf_0/ap_clk]
connect_bd_net [get_bd_ports aclk_0] [get_bd_pins axi4stream_vip_1/aclk]
endgroup

# Create and connect rstn port [aresetn_0]
startgroup
make_bd_pins_external  [get_bd_pins axi4stream_vip_0/aresetn]
connect_bd_net [get_bd_ports aresetn_0] [get_bd_pins top_intf_0/ap_rstn]
connect_bd_net [get_bd_ports aresetn_0] [get_bd_pins axi4stream_vip_1/aresetn]
connect_bd_net [get_bd_ports aresetn_0] [get_bd_pins top_intf_0/BRAM_PORTA_clk_a]
endgroup

# Make BRAM pins external
startgroup
make_bd_pins_external  [get_bd_pins top_intf_0/BRAM_PORTA_en_a]
make_bd_pins_external  [get_bd_pins top_intf_0/BRAM_PORTA_we_a]
make_bd_pins_external  [get_bd_pins top_intf_0/BRAM_PORTA_addr_a]
make_bd_pins_external  [get_bd_pins top_intf_0/BRAM_PORTA_wrdata_a]
endgroup

regenerate_bd_layout
validate_bd_design

make_wrapper -files [get_files ${FP_ROOT}/top_level_tb/top_level_tb.srcs/sources_1/bd/system/system.bd] -top

# Export output products --> generate VIP packages
export_ip_user_files -of_objects [get_files /home/jozmoz01/sandbox/fp_accel/top_level_tb/top_level_tb.srcs/sources_1/bd/system/system.bd] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] /home/jozmoz01/sandbox/fp_accel/top_level_tb/top_level_tb.srcs/sources_1/bd/system/system.bd]
launch_runs system_axi4stream_vip_0_0_synth_1 system_axi4stream_vip_1_0_synth_1 system_top_intf_0_0_synth_1 -jobs 8
export_simulation -of_objects [get_files /home/jozmoz01/sandbox/fp_accel/top_level_tb/top_level_tb.srcs/sources_1/bd/system/system.bd] -directory /home/jozmoz01/sandbox/fp_accel/top_level_tb/top_level_tb.ip_user_files/sim_scripts -ip_user_files_dir /home/jozmoz01/sandbox/fp_accel/top_level_tb/top_level_tb.ip_user_files -ipstatic_source_dir /home/jozmoz01/sandbox/fp_accel/top_level_tb/top_level_tb.ip_user_files/ipstatic -lib_map_path [list {modelsim=/home/jozmoz01/sandbox/fp_accel/top_level_tb/top_level_tb.cache/compile_simlib/modelsim} {questa=/home/jozmoz01/sandbox/fp_accel/top_level_tb/top_level_tb.cache/compile_simlib/questa} {xcelium=/home/jozmoz01/sandbox/fp_accel/top_level_tb/top_level_tb.cache/compile_simlib/xcelium} {vcs=/home/jozmoz01/sandbox/fp_accel/top_level_tb/top_level_tb.cache/compile_simlib/vcs} {riviera=/home/jozmoz01/sandbox/fp_accel/top_level_tb/top_level_tb.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet


save_bd_design
close_bd_design "system"

# Set test top
update_compile_order -fileset sim_1
set_property top top_level_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property top_file ${FP_ROOT}/src/verilog/sim_1/top_level_tb.sv [get_filesets sim_1]
update_compile_order -fileset sim_1
