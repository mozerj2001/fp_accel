startgroup
connect_bd_net [get_bd_pins tanimoto_1/BRAM_PORTA_addr_a] [get_bd_pins axi_bram_ctrl_0/bram_addr_a]
connect_bd_net [get_bd_pins axi_bram_ctrl_0/bram_clk_a] [get_bd_pins tanimoto_1/BRAM_PORTA_clk_a]
connect_bd_net [get_bd_pins tanimoto_1/BRAM_PORTA_wrdata_a] [get_bd_pins axi_bram_ctrl_0/bram_wrdata_a]
connect_bd_net [get_bd_pins axi_bram_ctrl_0/bram_rddata_a] [get_bd_pins tanimoto_1/BRAM_PORTA_rddata_a]
connect_bd_net [get_bd_pins tanimoto_1/BRAM_PORTA_en_a] [get_bd_pins axi_bram_ctrl_0/bram_en_a]
connect_bd_net [get_bd_pins axi_bram_ctrl_0/bram_rst_a] [get_bd_pins tanimoto_1/BRAM_PORTA_rst_a]
connect_bd_net [get_bd_pins tanimoto_1/BRAM_PORTA_we_a] [get_bd_pins axi_bram_ctrl_0/bram_we_a]
endgroup

regenerate_bd_layout
