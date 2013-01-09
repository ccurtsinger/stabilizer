ROOT = ../..
TARGETS = hello

build:: hello

include $(ROOT)/common.mk

CXX = $(ROOT)/szc -stabilizer=$(ROOT) -coderand -stackrand -heaprand -O3
CXXFLAGS =

$(OBJS):: $(ROOT)/szc $(ROOT)/LLVMStabilizer.$(SHLIB_SUFFIX)

test:: hello
	@echo $(INDENT)[test] Running 'hello'
	@echo
	@$(LD_PATH_VAR)=$(ROOT) ./hello
	@echo
