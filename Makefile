ROOT = .
DIRS = pass runtime

include $(ROOT)/common.mk

clean::
	@$(MAKE) -C tests clean

test: build
	@$(MAKE) -C tests test
