ROOT = ../..
TARGETS = hello

include $(ROOT)/common.mk

CXX = $(ROOT)/szc -stabilizer=$(ROOT) -coderand -stackrand -heaprand -O3
CXXFLAGS =

test:: hello
	@echo $(INDENT)[test] Running 'hello'
	@echo
	@$(LD_PATH_VAR)=$(ROOT) ./hello
	@echo
