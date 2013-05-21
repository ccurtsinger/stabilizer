
CC = gcc
CXX = g++

CFLAGS =
CXXFLAGS = $(CFLAGS)

SZCFLAGS = -frontend=clang
LD_PATH_VAR = LD_LIBRARY_PATH
CXXLIB = $(CXX) -shared
