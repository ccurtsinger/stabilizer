ROOT = ../..
TARGETS = perlbench
LIBS = m
SRCS = av.c deb.c doio.c doop.c dump.c globals.c gv.c hv.c locale.c mg.c numeric.c op.c pad.c perl.c perlapi.c perlio.c perlmain.c perly.c pp.c pp_ctl.c pp_hot.c pp_pack.c pp_sort.c pp_sys.c regcomp.c regexec.c run.c scope.c sv.c taint.c toke.c universal.c utf8.c util.c xsutils.c Base64.c Cwd.c Dumper.c HiRes.c IO.c Peek.c attrs.c poll.c stdio.c DynaLoader.c MD5.c Storable.c Parser.c specrand.c Hostname.c Opcode.c

build:: perlbench

include $(ROOT)/common.mk

CC = $(ROOT)/szc -coderand -O0
CXX = $(CC)
#CFLAGS = -DSPEC_CPU -DNEED_VA_COPY -DPERL_CORE -DSPEC_CPU_MACOSX -DSPEC_CPU_LP64
CFLAGS = -DSPEC_CPU -DPERL_CORE -DSPEC_CPU_LINUX_X64 -DSPEC_CPU_LP64
CXXFLAGS =

$(OBJS):: $(ROOT)/szc $(ROOT)/LLVMStabilizer.$(SHLIB_SUFFIX)

test:: perlbench
	@echo $(INDENT)[test] Running 'perlbench'
	@echo
	#@$(LD_PATH_VAR)=$(ROOT) ./perlbench -Ilib input/suns.pl
	@$(LD_PATH_VAR)=$(ROOT) ./perlbench -Ilib input/scrabbl.pl < input/scrabbl.in
	@$(LD_PATH_VAR)=$(ROOT) ./perlbench -Ilib input/splitmail.pl 535 13 25 24 1091
	@echo
