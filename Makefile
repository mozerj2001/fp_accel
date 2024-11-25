# ###########################################################
# ██████  ███    ███ ███████     ███    ███ ██ ████████ 
# ██   ██ ████  ████ ██          ████  ████ ██    ██    
# ██████  ██ ████ ██ █████       ██ ████ ██ ██    ██    
# ██   ██ ██  ██  ██ ██          ██  ██  ██ ██    ██    
# ██████  ██      ██ ███████     ██      ██ ██    ██    
# 2023-2024, Jozsef Mozer
# ###########################################################

# Ignore timing violations? --> ignore for bringup
ERROR_ON_HOLD_VIOLATION=FALSE


.PHONY: all kernel clean clean_platform platform rtl_xo hls_xo rtl_ip xclbin xclbin_debug docs

all: platform rtl_ip rtl_xo hls_xo xclbin

kernel: rtl_ip rtl_xo hls_xo xclbin
kernel_debug: rtl_ip rtl_xo hls_xo xclbin_debug

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
	vivado -mode batch -source scripting/package_ip.tcl -log ./logs/package_ip.log

rtl_xo:
	@echo "############################################################################"
	@echo "# CREATING RTL XO FILE"
	@echo "############################################################################"
	vivado -mode batch -source scripting/package_xo.tcl -log ./logs/rtl_xo.log

hls_xo:
	@echo "############################################################################"
	@echo "# CREATING DMA INTERFACE XO FILE"
	@echo "############################################################################"
	v++ -t hw \
		-c \
		--log_dir ./logs/hls_xo \
		--report_dir ./logs/hls_xo \
		--platform ./platform/WorkSpace/zcu106_custom/export/zcu106_custom/zcu106_custom.xpfm \
		--kernel_frequency 100 \
		-k hls_dma \
		./src/hls_dma/hls_dma.cpp \
		--save-temps \
		--temp_dir ./build/hls_if/build \
		-o ./build/hls_dma.xo

xclbin:
	@echo "############################################################################"
	@echo "# COMPILING XCLBIN"
	@echo "############################################################################"
	rm -rf _x
	rm -rf .Xil
	v++ -t hw \
    	--link \
		--log_dir ./logs/xclbin \
		--report_dir ./logs/xclbin \
		--advanced.param compiler.errorOnHoldViolation=${ERROR_ON_HOLD_VIOLATION} \
		--advanced.param compiler.userPostSysLinkOverlayTcl=scripting/post_link.tcl \
    	--platform ./platform/WorkSpace/zcu106_custom/export/zcu106_custom/zcu106_custom.xpfm \
    	--config ./scripting/connections.cfg \
    	./build/tanimoto.xo \
    	./build/hls_dma.xo \
    	--save-temps \
    	-o ./build/tanimoto_krnl.xclbin
	cp -rf ./_x/link/vivado/vpl/prj/prj.runs/impl_1/system_wrapper.bit ./platform/WorkSpace/petalinux_project/images/linux/system.bit

xclbin_debug:
	@echo "############################################################################"
	@echo "# COMPILING XCLBIN FOR ILA USE"
	@echo "############################################################################"
	rm -rf _x
	rm -rf .Xil
	v++ -t hw \
    	--link \
		--log_dir ./logs/xclbin \
		--report_dir ./logs/xclbin \
		--advanced.param compiler.errorOnHoldViolation=${ERROR_ON_HOLD_VIOLATION} \
		--advanced.param compiler.userPostSysLinkOverlayTcl=scripting/post_link.tcl \
    	--platform ./platform/WorkSpace/zcu106_custom/export/zcu106_custom/zcu106_custom.xpfm \
    	--config ./scripting/connections_debug.cfg \
    	./build/tanimoto.xo \
    	./build/hls_dma.xo \
    	--save-temps \
    	-o ./build/tanimoto_krnl.xclbin

clean_platform:
	rm -rf platform/WorkSpace/zcu106_custom_platform/
	rm -rf platform/WorkSpace/zcu106_custom/
	rm -rf platform/WorkSpace/device-tree-xlnx/
	rm -rf platform/WorkSpace/mydevice/
	rm -rf platform/WorkSpace/sysroot/
	rm -rf platform/WorkSpace/tmp/

clean_workspace:
	find platform/WorkSpace -mindepth 1 -maxdepth 1 \
				! -name 'app_component' \
				! -name 'device-tree-xlnx' \
				! -name 'Makefile' \
				! -name 'mydevice' \
				! -name 'petalinux_build.sh' \
				! -name 'petalinux_project' \
				! -name 'platform_creation.py' \
				! -name 'sysroot' \
				! -name 'system-user.dtsi' \
				! -name 'xilinx-zcu106-v2023.2-10140544.bsp' \
				! -name 'xilinx-zynqmp-common-v2023.2' \
				! -name 'zcu106_custom' \
				! -name 'zcu106_custom_platform' \
				! -name 'zcu106_custom_platform.tcl' \
				-exec rm -rf {} +

clean:
	@echo "############################################################################"
	@echo "# CLEANING UP OUTPUT FILES AND LOGFILES"
	@echo "# -- leaving output files of compile procedures"
	@echo "############################################################################"
	rm -rf logs
	find . -type f -name '*.log' -delete
	find . -type f -name '*.jou' -delete
	find . -type f -name '*.str' -delete
	find build/* ! -name 'tanimoto.xo' ! -name 'tanimoto_krnl.ltx' ! -name 'tanimoto_krnl.xclbin' ! -name 'hls_dma.xo' -delete
	rm -rf src/tanimoto_rtl
	rm -rf _x
	rm -rf top_level_tb
	find . -type d -name '.Xil' -exec bash -c 'rm -rf ${0}' {} \;
	rm -rf .ipcache

docs:
	rm -rf README.md
	cat docs/src_markdown/DOCS_HEADER.md > README.md
	@echo "## RTL Kernel" >> README.md
	cat docs/src_markdown/BIT_ADDER.md >> README.md
	cat docs/src_markdown/BIT_CNTR.md >> README.md
	cat docs/src_markdown/CNT1.md >> README.md
	cat docs/src_markdown/COMPARATOR.md >> README.md
	cat docs/src_markdown/VEC_CAT.md >> README.md
	cat docs/src_markdown/TANIMOTO_TOP.md >> README.md

help:
	@echo "platform: Create ZCU106 processor subsystem and the corresponding .xsa file."
	@echo "kernel: Create all parts of the PL kernel. (rtl_ip, rtl_xo, hls_xo)"
	@echo "rtl_ip: Create Vivado project from RTL sources and export .xsa file."
	@echo "rtl_xo: Generate .xo file containing the RTL kernel."
	@echo "hls_xo: Generate .xo file of the interface written in HLS."
	@echo "xclbin: Generate .xclbin file that can be used as an OpenCL target in Vitis."
	@echo "all: All of the above."
	@echo "clean: Remove all generated and build files, except for platform build results and final .xo files."
	@echo "clean_platform: Remove zcu106_custom_platform and zcu106_custom."
	@echo "clean_workspace: Clean Vitis workspace files. Needs to be run for Vitis GUI to recognize platforms and the app_component."
	@echo "docs: Compile documentation to README.md."
	@echo "help: Print this message."
