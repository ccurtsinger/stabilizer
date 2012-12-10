ROOT = ..

TARGETS = $(ROOT)/libstabilizer.$(SHLIB_SUFFIX)
LIBS = 
INCLUDE_DIRS = $(ROOT)/Heap-Layers \
    $(ROOT)/DieHard/src/include \
    $(ROOT)/DieHard/src/include/math \
    $(ROOT)/DieHard/src/include/static \
    $(ROOT)/DieHard/src/include/rng \
    $(ROOT)/DieHard/src/include/layers \
    $(ROOT)/DieHard/src/include/util

include $(ROOT)/common.mk

CFLAGS += -DNDEBUG
CXXFLAGS += -DNDEBUG
