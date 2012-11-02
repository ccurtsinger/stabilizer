ROOT = ../..
TARGETS = hello

include $(ROOT)/common.mk

CXX = $(ROOT)/szc -stabilizer=$(ROOT) -osx -coderand -stackrand -heaprand -O3
CXXFLAGS =

test:: hello
	$(LD_PATH_VAR)=$(ROOT) ./hello
