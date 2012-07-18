LEVEL = ../..

#LIBRARYNAME = libstabilizer
#LOADABLE_MODULE = 1

LIBRARYNAME = stabilizer
BUILD_ARCHIVE = 1

include $(LEVEL)/Makefile.common

CPPFLAGS += --std=c++0x -fexceptions \
	-I. \
	-I./diehard/src/include \
	-I./diehard/src/include/layers \
	-I./diehard/src/include/util \
	-I./diehard/src/include/rng \
	-I./diehard/src/include/static \
	-I./diehard/src/include/math \
	-I./diehard/src/Heap-Layers \
	-DNDEBUG

