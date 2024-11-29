set FP_ROOT $env(FP_ROOT)

# Set up platform project
create_project zcu106_custom_platform ${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform -part xczu7ev-ffvc1156-2-e

set_property board_part xilinx.com:zcu106:part0:2.6 [current_project]
set_property platform.extensible true [current_project]

create_bd_design "system"

# Instantiate processor system
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ultra_ps_e_0]
endgroup

# Set up clock generation
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0

set_property -dict [list CONFIG.RESET_PORT {resetn} CONFIG.RESET_TYPE {ACTIVE_LOW}] [get_bd_cells clk_wiz_0]

endgroup

# Add system reset
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0
endgroup

# Connect clock and reset
startgroup
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins clk_wiz_0/resetn]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins clk_wiz_0/clk_in1]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins proc_sys_reset_0/dcm_locked]
connect_bd_net [get_bd_pins proc_sys_reset_0/ext_reset_in] [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]

set_property -dict [list \
  CONFIG.CLKOUT1_JITTER {132.698} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100} \
] [get_bd_cells clk_wiz_0]
endgroup

# Set default clock
set_property PFM.CLOCK {clk_out1 {id "1" is_default "true" proc_sys_reset "/proc_sys_reset_0" status "fixed" freq_hz "99990000"}} [get_bd_cells /clk_wiz_0]

# Enable M_AXI_HPM0_LPD, disable FPD
startgroup
set_property -dict [list \
  CONFIG.PSU__USE__M_AXI_GP2 {1} \
  CONFIG.PSU__USE__M_AXI_GP0 {0} \
  CONFIG.PSU__USE__M_AXI_GP1 {0} \
] [get_bd_cells zynq_ultra_ps_e_0]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk] [get_bd_pins clk_wiz_0/clk_out1]
endgroup

# Add and connect AXI BRAM Controller and AXI Interconnect
startgroup

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
set_property CONFIG.SINGLE_PORT_BRAM {1} [get_bd_cells axi_bram_ctrl_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
set_property -dict [list CONFIG.ENABLE_ADVANCED_OPTIONS {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_interconnect_0]

connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_interconnect_0/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_LPD]
connect_bd_intf_net [get_bd_intf_pins axi_bram_ctrl_0/S_AXI] -boundary_type upper [get_bd_intf_pins axi_interconnect_0/M00_AXI]

connect_bd_net [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins clk_wiz_0/clk_out1]

connect_bd_net [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]

endgroup

# Enable and configure AXI ports
startgroup
set_property PFM.AXI_PORT {M01_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M02_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M03_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M04_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M05_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M06_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M07_AXI {memport "M_AXI_GP" sptag "" memory "" is_range "false"}} [get_bd_cells /axi_interconnect_0]
# set_property PFM.AXI_PORT {M_AXI_HPM0_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M_AXI_HPM1_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"}} [get_bd_cells /zynq_ultra_ps_e_0]
# set_property PFM.AXI_PORT {M_AXI_HPM0_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M_AXI_HPM1_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} S_AXI_HPC0_FPD {memport "S_AXI_HPC" sptag "" memory "" is_range "false"} S_AXI_HPC1_FPD {memport "S_AXI_HPC" sptag "" memory "" is_range "false"} S_AXI_HP0_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP1_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP2_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP3_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"}} [get_bd_cells /zynq_ultra_ps_e_0]
# set_property PFM.AXI_PORT {M_AXI_HPM0_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M_AXI_HPM1_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} S_AXI_HPC0_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HPC1_FPD {memport "S_AXI_HPC" sptag "" memory "" is_range "false"} S_AXI_HP0_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP1_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP2_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP3_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"}} [get_bd_cells /zynq_ultra_ps_e_0]
# set_property PFM.AXI_PORT {M_AXI_HPM0_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M_AXI_HPM1_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} S_AXI_HPC0_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HPC1_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP0_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP1_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP2_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP3_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"}} [get_bd_cells /zynq_ultra_ps_e_0]
# set_property PFM.AXI_PORT {M_AXI_HPM0_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M_AXI_HPM1_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} S_AXI_HPC0_FPD {memport "S_AXI_HP" sptag "HPC0" memory "" is_range "false"} S_AXI_HPC1_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP0_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP1_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP2_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP3_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"}} [get_bd_cells /zynq_ultra_ps_e_0]
# set_property PFM.AXI_PORT {M_AXI_HPM0_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M_AXI_HPM1_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} S_AXI_HPC0_FPD {memport "S_AXI_HP" sptag "HPC0" memory "" is_range "false"} S_AXI_HPC1_FPD {memport "S_AXI_HP" sptag "HPC1" memory "" is_range "false"} S_AXI_HP0_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP1_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP2_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP3_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"}} [get_bd_cells /zynq_ultra_ps_e_0]
# set_property PFM.AXI_PORT {M_AXI_HPM0_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M_AXI_HPM1_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} S_AXI_HPC0_FPD {memport "S_AXI_HP" sptag "HPC0" memory "" is_range "false"} S_AXI_HPC1_FPD {memport "S_AXI_HP" sptag "HPC1" memory "" is_range "false"} S_AXI_HP0_FPD {memport "S_AXI_HP" sptag "HP0" memory "" is_range "false"} S_AXI_HP1_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP2_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP3_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"}} [get_bd_cells /zynq_ultra_ps_e_0]
# set_property PFM.AXI_PORT {M_AXI_HPM0_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M_AXI_HPM1_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} S_AXI_HPC0_FPD {memport "S_AXI_HP" sptag "HPC0" memory "" is_range "false"} S_AXI_HPC1_FPD {memport "S_AXI_HP" sptag "HPC1" memory "" is_range "false"} S_AXI_HP0_FPD {memport "S_AXI_HP" sptag "HP0" memory "" is_range "false"} S_AXI_HP1_FPD {memport "S_AXI_HP" sptag "HP1" memory "" is_range "false"} S_AXI_HP2_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"} S_AXI_HP3_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"}} [get_bd_cells /zynq_ultra_ps_e_0]
# set_property PFM.AXI_PORT {M_AXI_HPM0_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M_AXI_HPM1_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} S_AXI_HPC0_FPD {memport "S_AXI_HP" sptag "HPC0" memory "" is_range "false"} S_AXI_HPC1_FPD {memport "S_AXI_HP" sptag "HPC1" memory "" is_range "false"} S_AXI_HP0_FPD {memport "S_AXI_HP" sptag "HP0" memory "" is_range "false"} S_AXI_HP1_FPD {memport "S_AXI_HP" sptag "HP1" memory "" is_range "false"} S_AXI_HP2_FPD {memport "S_AXI_HP" sptag "HP2" memory "" is_range "false"} S_AXI_HP3_FPD {memport "S_AXI_HP" sptag "" memory "" is_range "false"}} [get_bd_cells /zynq_ultra_ps_e_0]
set_property PFM.AXI_PORT {M_AXI_HPM0_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} M_AXI_HPM1_FPD {memport "M_AXI_GP" sptag "" memory "" is_range "false"} S_AXI_HPC0_FPD {memport "S_AXI_HP" sptag "HPC0" memory "" is_range "false"} S_AXI_HPC1_FPD {memport "S_AXI_HP" sptag "HPC1" memory "" is_range "false"} S_AXI_HP0_FPD {memport "S_AXI_HP" sptag "HP0" memory "" is_range "false"} S_AXI_HP1_FPD {memport "S_AXI_HP" sptag "HP1" memory "" is_range "false"} S_AXI_HP2_FPD {memport "S_AXI_HP" sptag "HP2" memory "" is_range "false"} S_AXI_HP3_FPD {memport "S_AXI_HP" sptag "HP3" memory "" is_range "false"}} [get_bd_cells /zynq_ultra_ps_e_0]
endgroup

# Wrap up and generate .xsa files
regenerate_bd_layout
validate_bd_design

make_wrapper -files [get_files ${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.srcs/sources_1/bd/system/system.bd] -top
add_files -norecurse ${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.gen/sources_1/bd/system/hdl/system_wrapper.v

set_property synth_checkpoint_mode None [get_files  ${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.srcs/sources_1/bd/system/system.bd]
generate_target all [get_files  ${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.srcs/sources_1/bd/system/system.bd]
export_ip_user_files -of_objects [get_files ${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.srcs/sources_1/bd/system/system.bd] -no_script -sync -force -quiet
export_simulation -of_objects [get_files ${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.srcs/sources_1/bd/system/system.bd] -directory ${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.ip_user_files/sim_scripts -ip_user_files_dir ${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.ip_user_files -ipstatic_source_dir ${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.ip_user_files/ipstatic -lib_map_path [list {modelsim=${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.cache/compile_simlib/modelsim} {questa=${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.cache/compile_simlib/questa} {xcelium=${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.cache/compile_simlib/xcelium} {vcs=${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.cache/compile_simlib/vcs} {riviera=${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet

launch_runs synth_1 -jobs 6
launch_runs impl_1 -jobs 6

set_property platform.name {zcu106_custom_platform} [current_project]
set_property pfm_name {xilinx:zcu106:zcu106_custom_platform:0.0} [get_files -all {${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform.srcs/sources_1/bd/system/system.bd}]
set_property platform.design_intent.embedded {true} [current_project]
set_property platform.design_intent.datacenter {false} [current_project]
set_property platform.design_intent.server_managed {false} [current_project]
set_property platform.design_intent.external_host {false} [current_project]
set_property platform.default_output_type {sd_card} [current_project]
set_property platform.uses_pr {false} [current_project]

write_hw_platform -hw -force -file ${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform_hw.xsa
write_hw_platform -hw_emu -force -file ${FP_ROOT}/platform/WorkSpace/zcu106_custom_platform/zcu106_custom_platform_hwemu.xsa


