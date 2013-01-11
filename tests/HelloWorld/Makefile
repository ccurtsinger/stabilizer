ROOT = ../..
TARGETS = hello

build:: hello

include $(ROOT)/common.mk

CC = $(ROOT)/szc $(SZCFLAGS) -Rcode -Rheap -Rstack
CXX = $(CC)
CXXFLAGS =

$(OBJS):: $(ROOT)/szc $(ROOT)/LLVMStabilizer.$(SHLIB_SUFFIX)

test:: hello
	@echo $(INDENT)[test] Running 'hello'
	@echo
	@$(LD_PATH_VAR)=$(ROOT) ./hello
	@echo
