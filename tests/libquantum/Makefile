ROOT = ../..
TARGETS = libquantum

include $(ROOT)/common.mk

CC = $(ROOT)/szc -stabilizer=$(ROOT) -osx -coderand -stackrand -heaprand -O3
CXX = $(CC)
CFLAGS = -DSPEC_CPU -DSPEC_CPU_MACOSX
CXXFLAGS =

test:: libquantum
	$(LD_PATH_VAR)=$(ROOT) ./libquantum 128
