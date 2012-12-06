ROOT = ../..
TARGETS = libquantum

build:: libquantum

include $(ROOT)/common.mk

CC = $(ROOT)/szc -stabilizer=$(ROOT) -osx -coderand -stackrand -O3
CXX = $(CC)
CFLAGS = -DSPEC_CPU -DSPEC_CPU_MACOSX
CXXFLAGS =

$(TARGETS):: $(ROOT)/szc $(ROOT)/libstabilizer.$(SHLIB_SUFFIX)
$(OBJS):: $(ROOT)/szc $(ROOT)/LLVMStabilizer.$(SHLIB_SUFFIX)

test:: libquantum
	@echo $(INDENT)[test] Running 'libquantum'
	@echo
	@$(LD_PATH_VAR)=$(ROOT) ./libquantum 128
	@echo
