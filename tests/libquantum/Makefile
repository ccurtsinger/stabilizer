ROOT = ../..
TARGETS = libquantum

build:: libquantum

include $(ROOT)/common.mk

CC = $(ROOT)/szc $(SZCFLAGS) -Rcode -Rheap -Rstack
CXX = $(CC)
CFLAGS = -DSPEC_CPU -DSPEC_CPU_MACOSX
CXXFLAGS =

$(OBJS):: $(ROOT)/szc $(ROOT)/LLVMStabilizer.$(SHLIB_SUFFIX)

test:: libquantum
	@echo $(INDENT)[test] Running 'libquantum'
	@echo
	@$(LD_PATH_VAR)=$(ROOT) ./libquantum 128
	@echo
