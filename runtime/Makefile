LEVEL=..
LIBRARYNAME = libstabilizer
LOADABLE_MODULE = 1
USEDLIBS = 

include $(LEVEL)/Makefile.common

CXX = clang++

CFLAGS += -DUSE_DL_PREFIX -DNDEBUG
CXXFLAGS += --std=c++0x -DNDEBUG -I. -fexceptions -Wno-pedantic \
	-I hl \
	-I dh/src/include \
	-I dh/src/include/rng \
	-I dh/src/include/math \
	-I dh/src/include/util \
	-I dh/src/include/layers \
	-I dh/src/include/static