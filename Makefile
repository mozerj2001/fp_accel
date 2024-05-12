# ###########################################################
# ██████  ███    ███ ███████     ███    ███ ██ ████████ 
# ██   ██ ████  ████ ██          ████  ████ ██    ██    
# ██████  ██ ████ ██ █████       ██ ████ ██ ██    ██    
# ██   ██ ██  ██  ██ ██          ██  ██  ██ ██    ██    
# ██████  ██      ██ ███████     ██      ██ ██    ██    
# 2023-2024, Jozsef Mozer
# ###########################################################

.PHONY: all clean xo ip
all: ip xo

ip:
	vivado -mode batch -source scripting/package_ip.tcl

xo:
	vivado -mode batch -source scripting/package_xo.tcl

clean:
	find . -type f -name '*.log' -delete
	find . -type f -name '*.jou' -delete
	rm -rf tanimoto_rtl/tanimoto_rtl.cache
	rm -rf tanimoto_rtl/tanimoto_rtl.gen
	rm -rf tanimoto_rtl/tanimoto_rtl.hw
	rm -rf tanimoto_rtl/tanimoto_rtl.ip_user_files
	rm -rf tanimoto_rtl/tanimoto_rtl.srcs
	rm -rf tanimoto_rtl/tanimoto_rtl.sim
	rm -rf tanimoto_rtl/tanimoto_rtl.xpr
	rm -rf tanimoto_rtl/tanimoto_rtl.runs
