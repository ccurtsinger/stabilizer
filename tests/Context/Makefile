ROOT = ../..

include $(ROOT)/common.mk

test:: hello.cpp stub.asm
	yasm -o stub.o -f macho64 stub.asm
	clang++ -g -I$(ROOT)/runtime -o hello hello.cpp stub.o
	./hello
