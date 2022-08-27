# COCOTB variables
export COCOTB_REDUCED_LOG_FMT=1
export PYTHONPATH := test:$(PYTHONPATH)
export LIBPYTHON_LOC=$(shell cocotb-config --libpython)

all: test_sys


# test_sys:
# 	rm -rf sim_build/ results.xml
# 	mkdir sim_build/
# 	iverilog -o sim_build/sim.vvp -s edu_tpu -s dump src/sysa.v src/sysa_pe.v src/edu_tpu.v src/async_fifo.v src/fifo_2mem.v src/rptr_empty.v src/sync_r2w.v src/sync_w2r.v src/wptr_full.v test/dump_sys.v
# 	PYTHONOPTIMIZE=${NOASSERT} MODULE=test_etpu_wb vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
# ! grep failure results.xml

# test_sys:
# 	rm -rf sim_build/ results.xml
# 	mkdir sim_build/
# 	iverilog -o sim_build/sim.vvp -s edu_tpu -s dump src/sysa.v src/sysa_pe.v src/edu_tpu.v src/dffram_tpu.v src/async_fifo.v src/fifo_2mem.v src/rptr_empty.v src/sync_r2w.v src/sync_w2r.v src/wptr_full.v test/dump_sys.v
# 	PYTHONOPTIMIZE=${NOASSERT} MODULE=test_ram vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
# 	! grep failure results.xml

# test_sys:
# 	rm -rf sim_build/ results.xml
# 	mkdir sim_build/
# 	iverilog -o sim_build/sim.vvp -s edu_tpu -s dump src/sysa_pe.v src/edu_tpu.v src/dffram.v test/dump_sys.v
# 	PYTHONOPTIMIZE=${NOASSERT} MODULE=test_ram vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
# 	! grep failure results.xml

# test_sys:
# 	rm -rf sim_build/ results.xml
# 	mkdir sim_build/
# 	iverilog -o sim_build/sim.vvp -s edu_tpu -s dump src/sysa_pe.v src/edu_tpu.v src/dffram_tpu.v test/dump_sys.v
# 	PYTHONOPTIMIZE=${NOASSERT} MODULE=test_ram vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
# 	! grep failure results.xml

test_sys:
	rm -rf sim_build/ results.xml
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s edu_tpu -s dump src/sysa_pe.v src/edu_tpu.v src/npu_wb.v test/dump_sys.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test_ram vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

show_%: %.vcd %.gtkw
	gtkwave $^

lint:
	verible-verilog-lint src/*v --rules_config verible.rules

clean:
	rm -rf *vcd sim_build test/__pycache__ results.xml

.PHONY: clean
