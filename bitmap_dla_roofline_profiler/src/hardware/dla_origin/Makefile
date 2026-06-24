BIN0 = obj_dir/Vasic_wrapper
LIB0 = obj_dir/libVasic_wrapper.a

SRC := $(shell find ./ASIC ! -name .sv | grep sv)
HDR := $(wildcard include/*.svh)
INCLUDE := -Iinclude
VFLAGS := -Wall -Wno-lint -Wno-style --cc --trace-fst --top-module asic_wrapper -sv
VC := verilator

VERILATOR_ROOT := /usr/local/share/verilator
VERILATOR_SOURCES := $(VERILATOR_ROOT)/include/verilated.cpp \
                     $(VERILATOR_ROOT)/include/verilated_fst_c.cpp \
                     $(VERILATOR_ROOT)/include/verilated_threads.cpp

.PHONY: all clean format

all: $(LIB0)

obj_dir/Vasic_wrapper: $(SRC) $(HDR)
	$(VC) $(VFLAGS) $(INCLUDE) $(SRC)

$(LIB0): obj_dir/Vasic_wrapper
	cd obj_dir && g++ -c -fPIC -I$(VERILATOR_ROOT)/include $(VERILATOR_SOURCES) && g++ -c -fPIC -I$(VERILATOR_ROOT)/include *.cpp && ar rcs $(notdir $(LIB0)) *.o && rm -f *.o

format:
	clang-format -i tb/*.cpp

clean:
	$(RM) -rv obj_dir
