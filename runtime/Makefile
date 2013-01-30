ROOT = ..
CROSS_TARGET = 1
TARGETS = $(ROOT)/libstabilizer.$(SHLIB_SUFFIX) $(ROOT)/libstabilizer.a
INCLUDE_DIRS = $(ROOT)/Heap-Layers \
    $(ROOT)/DieHard/src/include \
    $(ROOT)/DieHard/src/include/math \
    $(ROOT)/DieHard/src/include/rng \
    $(ROOT)/DieHard/src/include/static \
    $(ROOT)/DieHard/src/include/util

include $(ROOT)/common.mk

CFLAGS += -Os -g
CXXFLAGS += -Os -g
