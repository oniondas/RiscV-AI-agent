all: sim

sim: rtl/*.v sim_main.cpp
	verilator --cc --exe --build -j 0 -Wall -Wno-UNUSED -Wno-CASEINCOMPLETE -Wno-LATCH -Wno-WIDTH -Wno-WIDTHTRUNC -Wno-MULTIDRIVEN rtl/*.v sim_main.cpp --top-module rv32i_core

test: sim
	./obj_dir/Vrv32i_core firmware.bin

clean:
	rm -rf obj_dir
