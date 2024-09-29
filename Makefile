# ###########################################################
# ██████  ███    ███ ███████     ███    ███ ██ ████████ 
# ██   ██ ████  ████ ██          ████  ████ ██    ██    
# ██████  ██ ████ ██ █████       ██ ████ ██ ██    ██    
# ██   ██ ██  ██  ██ ██          ██  ██  ██ ██    ██    
# ██████  ██      ██ ███████     ██      ██ ██    ██    
# 2023-2024, Jozsef Mozer
# ###########################################################

.PHONY: all kernel clean clean_platform platform rtl_xo hls_xo rtl_ip xclbin

all: platform rtl_ip rtl_xo hls_xo xclbin

kernel: rtl_ip rtl_xo hls_xo

platform:
	@echo "############################################################################"
	@echo "# CREATING PS PLATFORM"
	@echo "############################################################################"
	cd platform/WorkSpace/;	vivado -mode batch -script zcu106_custom_platform.tcl
	cd platform/WorkSpace/; make all COMMON_IMAGE_ZYNQMP=xilinx-zynqmp-common-v2023.2/


rtl_ip:
	@echo "############################################################################"
	@echo "# PACKAGING RTL IP"
	@echo "############################################################################"
	vivado -mode batch -source scripting/package_ip.tcl

rtl_xo:
	@echo "############################################################################"
	@echo "# CREATING RTL XO FILE"
	@echo "############################################################################"
	vivado -mode batch -source scripting/package_xo.tcl

hls_xo:
	@echo "############################################################################"
	@echo "# CREATING HLS INTERFACE XO FILE"
	@echo "############################################################################"
	v++ -t hw \
		-c \
		--platform ./platform/WorkSpace/zcu106_custom/export/zcu106_custom/zcu106_custom.xpfm \
		--kernel_frequency 100 \
		-k tan_intf \
		./hls_if/tan_intf.cpp ./hls_if/threshold_intf.cpp ./hls_if/vec_intf.cpp \
		--save-temps \
		--temp_dir ./hls_if/build \
		-o ./tan_intf.xo

xclbin:
	@echo "############################################################################"
	@echo "# COMPILING XCLBIN"
	@echo "############################################################################"
	v++ -t hw \
    	--link \
    	--platform ./platform/WorkSpace/zcu106_custom/export/zcu106_custom/zcu106_custom.xpfm \
    	--config ./scripting/connections.cfg \
    	./tanimoto.xo \
    	./tan_intf.xo \
    	--save-temps \
    	-o tanimoto_krnl.xclbin

clean_platform:
	rm -rf platform/WorkSpace/zcu106_custom_platform/
	rm -rf platform/WorkSpace/zcu106_custom/


clean:
	@echo "############################################################################"
	@echo "# CLEANING UP WORKSPACE"
	@echo "############################################################################"
	find . -type f -name '*.log' -delete
	find . -type f -name '*.jou' -delete
	find . -type f -name '*.str' -delete
	rm -rf tanimoto_rtl/tanimoto_rtl.cache
	rm -rf tanimoto_rtl/tanimoto_rtl.gen
	rm -rf tanimoto_rtl/tanimoto_rtl.hw
	rm -rf tanimoto_rtl/tanimoto_rtl.ip_user_files
	rm -rf tanimoto_rtl/tanimoto_rtl.srcs
	rm -rf tanimoto_rtl/tanimoto_rtl.sim
	rm -rf tanimoto_rtl/tanimoto_rtl.xpr
	rm -rf tanimoto_rtl/tanimoto_rtl.runs
	rm -rf hls_if/build
	rm -rf _x
	rm -rf .Xil
	rm -rf platform/WorkSpace/.Xil
	rm tan_intf.xo.compile_summary
	rm tanimoto_krnl.xclbin.link_summary

help:
	@echo "platform: Create ZCU106 processor subsystem and the corresponding .xsa file."
	@echo "kernel: Create all parts of the PL kernel. (rtl_ip, rtl_xo, hls_xo)"
	@echo "rtl_ip: Create Vivado project from RTL sources and export .xsa file."
	@echo "rtl_xo: Generate .xo file containing the RTL kernel."
	@echo "hls_xo: Generate .xo file of the interface written in HLS."
	@echo "xclbin: Generate .xclbin file that can be used as an OpenCL target in Vitis."
	@echo "clean: Remove all generated and build files, except for platform build results and final .xo files."
	@echo "clean_platform: Remove zcu106_custom_platform and zcu106_custom."
	@echo "all: All of the above."

	@echo "help: Print this message."
