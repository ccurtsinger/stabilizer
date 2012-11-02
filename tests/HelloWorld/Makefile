ROOT = ../..

include $(ROOT)/common.mk

test:: hello.cpp $(ROOT)/szc $(ROOT)/LLVMStabilizer.$(SHLIB_SUFFIX) $(ROOT)/libstabilizer.$(SHLIB_SUFFIX)
	$(ROOT)/szc hello.cpp -o hello -stabilizer=$(ROOT) -osx -coderand -stackrand -heaprand -lgtest
	$(LD_PATH_VAR)=$(ROOT) ./hello
