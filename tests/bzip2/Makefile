ROOT = ../..
TARGETS = bzip2

build:: bzip2

include $(ROOT)/common.mk

CC = $(ROOT)/szc -stabilizer=$(ROOT) -O3
CXX = $(CC)
CFLAGS = -DSPEC_CPU -DSPEC_CPU_MACOSX
CXXFLAGS =

$(OBJS):: $(ROOT)/szc $(ROOT)/LLVMStabilizer.$(SHLIB_SUFFIX)

test:: bzip2
	@echo $(INDENT)[test] Running 'bzip2'
	@echo
	@$(LD_PATH_VAR)=$(ROOT) ./bzip2 input.combined
	@echo
