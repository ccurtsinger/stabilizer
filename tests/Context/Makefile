ROOT = ../..

include $(ROOT)/common.mk

test:: hello.cpp stub.asm
	yasm -o stub.o -f macho64 stub.asm
	clang++ -o hello hello.cpp stub.o
	./hello
