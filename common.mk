# Build with clang
CC  := /usr/bin/clang
CXX := /usr/bin/clang++

# LLVM bitcode commands
CCBC  := clang -emit-llvm
CXXBC := clang++ -emit-llvm
BCLINK := llvm-link

# Default flags
CFLAGS   ?= -g -O2
CXXFLAGS ?= $(CFLAGS)
LDFLAGS  += $(addprefix -l,$(LIBS))

# Default source and object files
SRCS ?= $(wildcard *.cpp) $(wildcard *.c)
OBJS ?= $(addprefix obj/,$(patsubst %.cpp,%.o,$(patsubst %.c,%.o,$(SRCS))))
BCS  ?= $(addprefix bc/,$(patsubst %.cpp,%.bc,$(patsubst %.c,%.bc,$(SRCS))))  

# Targets to build recirsively into $(DIRS)
RECURSIVE_TARGETS  ?= all clean bench test

# Build in parallel
MAKEFLAGS := -j

# Targets separated by type
SHARED_LIB_TARGETS := $(filter %.so, $(TARGETS))
STATIC_LIB_TARGETS := $(filter %.a, $(TARGETS))
BITCODE_TARGETS    := $(filter %.bc, $(TARGETS))
OTHER_TARGETS      := $(filter-out %.bc, $(filter-out %.so, $(filter-out %.a, $(TARGETS))))

# If not set, the build path is just the current directory name
MAKEPATH ?= `basename $(PWD)`

# Log the build path in gray, following by a log message in bold green
LOG_PREFIX := "\033[37;0m[$(MAKEPATH)]\033[0m\033[32;1m"
LOG_SUFFIX := "\033[0m"

# Build all targets by default
all:: $(TARGETS)

# Clean up after a bild
clean::
	@for t in $(TARGETS); do \
	echo $(LOG_PREFIX) Cleaning $$t $(LOG_SUFFIX); \
	done
	@rm -rf $(TARGETS) obj

# Prevent errors if files named all, clean, bench, or test exist
.PHONY: all clean bench test

# Compile a C++ source file (and generate its dependency rules)
obj/%.o: %.cpp $(PREREQS)
	@echo $(LOG_PREFIX) Compiling $< $(LOG_SUFFIX)
	@mkdir -p obj
	@$(CXX) $(CXXFLAGS) -MMD -MP -o $@ -c $<

# Compile a C source file (and generate its dependency rules)
obj/%.o: %.c $(PREREQS)
	@echo $(LOG_PREFIX) Compiling $< $(LOG_SUFFIX)
	@mkdir -p obj
	@$(CC) $(CFLAGS) -MMD -MP -o $@ -c $<

# Compile a C++ source file to bitcode (and generate its dependency rules)
bc/%.bc: %.cpp $(PREREQS)
	@echo $(LOG_PREFIX) Compiling $< to LLVM bitcode $(LOG_SUFFIX)
	@mkdir -p bc
	@$(CXXBC) $(CXXFLAGS) -MMD -MP -o $@ -c $<

# Compile a C source file to bitecode (and generate its dependency rules)
bc/%.bc: %.c $(PREREQS)
	@echo $(LOG_PREFIX) Compiling $< to LLVM bitcode $(LOG_SUFFIX)
	@mkdir -p bc
	@$(CCBC) $(CFLAGS) -MMD -MP -o $@ -c $<

# Link a shared library 
$(SHARED_LIB_TARGETS): $(OBJS)
	@echo $(LOG_PREFIX) Linking $@ $(LOG_SUFFIX)
	@$(CXX) -shared $(LDFLAGS) -o $@ $^

# Link bitcode targets
$(BITCODE_TARGETS): $(BCS)
	@echo $(LOG_PREFIX) Linking $@ $(LOG_SUFFIX)
	@$(BCLINK) -o $@ $^

# Link binary targets
$(OTHER_TARGETS): $(OBJS)
	@echo $(LOG_PREFIX) Linking $@ $(LOG_SUFFIX)
	@$(CXX) $(LDFLAGS) -o $@ $^

# Include dependency rules for all objects
-include $(OBJS:.o=.d)
-include $(BCS:.bc=.d)

# Build any recursive targets in subdirectories
$(RECURSIVE_TARGETS)::
	@for dir in $(DIRS); do \
	$(MAKE) -C $$dir --no-print-directory $@ MAKEPATH="$(MAKEPATH)/$$dir"; \
	done