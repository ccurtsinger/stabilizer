ROOT 		:= ..
TARGETS := jit

LLVM_COMPONENTS := interpreter jit mcjit native irreader core
CXXFLAGS := --std=c++11 -g -O2 $(shell llvm-config --cxxflags)
LDFLAGS  := $(shell llvm-config --ldflags --libs --system-libs $(LLVM_COMPONENTS))

include $(ROOT)/common.mk
