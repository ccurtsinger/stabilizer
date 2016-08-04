# Get the current OS and architecture
OS ?= $(shell uname -s)
CPU ?= $(shell uname -m)
PLATFORM ?= $(OS).$(CPU)
TARGET_PLATFORM ?= $(PLATFORM)

# Set the default compilers and flags
CC = clang
CXX = clang++
CFLAGS ?= -Os
CXXFLAGS ?= $(CFLAGS)

# Include platform-specific rules
ifneq ($(CROSS_TARGET),)
	include $(ROOT)/platforms/$(TARGET_PLATFORM).mk
else
	include $(ROOT)/platforms/$(PLATFORM).mk
endif

# Set the default shared library filename suffix
SHLIB_SUFFIX ?= so

# Don't build into subdirectories by default
DIRS ?=

# Don't require any libraries by default
LIBS ?= 

# Set the default include directories
INCLUDE_DIRS ?= 

# Recurse into subdirectories for the 'clean' and 'build' targets
RECURSIVE_TARGETS ?= clean build

# Build by default
all: debug

# Just remove the targets
clean::
ifneq ($(TARGETS),)
	@rm -f $(TARGETS)
endif

# Set the default source and include files with wildcards
SRCS ?= $(wildcard *.c) $(wildcard *.cpp) $(wildcard *.cc) $(wildcard *.C)
OBJS ?= $(addprefix obj/, $(patsubst %.c, %.o, $(patsubst %.cpp, %.o, $(patsubst %.cc, %.o, $(patsubst %.C, %.o, $(SRCS))))))
INCLUDES ?= $(wildcard *.h) $(wildcard *.hpp) $(wildcard *.hh) $(wildcard *.H) $(wildcard $(addsuffix /*.h, $(INCLUDE_DIRS))) $(wildcard $(addsuffix /*.hpp, $(INCLUDE_DIRS))) $(wildcard $(addsuffix /*.hh, $(INCLUDE_DIRS))) $(wildcard $(addsuffix /*.H, $(INCLUDE_DIRS)))

# Clean up objects
clean::
ifneq ($(OBJS),)
	@rm -f $(OBJS)
endif

INDENT +=" "
export INDENT

# Generate flags to link required libraries and get includes
LIBFLAGS = $(addprefix -l, $(LIBS))
INCFLAGS = $(addprefix -I, $(INCLUDE_DIRS))

SHARED_LIB_TARGETS = $(filter %.$(SHLIB_SUFFIX), $(TARGETS))
STATIC_LIB_TARGETS = $(filter %.a, $(TARGETS))
OTHER_TARGETS = $(filter-out %.$(SHLIB_SUFFIX), $(filter-out %.a, $(TARGETS)))

release: DEBUG=
release: build

debug: DEBUG=1
debug: build

build:: $(TARGETS) $(INCLUDE_DIRS)

obj/%.o:: %.c Makefile $(ROOT)/common.mk $(INCLUDE_DIRS) $(INCLUDES)
	@mkdir -p obj
	@echo $(INDENT)[$(notdir $(firstword $(CC)))] Compiling $< for $(if $(DEBUG),Debug,Release) build
	@$(CC) $(CFLAGS) $(if $(DEBUG),-g,-DNDEBUG) $(INCFLAGS) -c $< -o $@

obj/%.o:: %.cpp Makefile $(ROOT)/common.mk $(INCLUDE_DIRS) $(INCLUDES)
	@mkdir -p obj
	@echo $(INDENT)[$(notdir $(firstword $(CXX)))] Compiling $< for $(if $(DEBUG),Debug,Release) build
	@$(CXX) $(CXXFLAGS) $(if $(DEBUG),-g,-DNDEBUG) $(INCFLAGS) -c $< -o $@
	
obj/%.o:: %.cc Makefile $(ROOT)/common.mk $(INCLUDE_DIRS) $(INCLUDES)
	@mkdir -p obj
	@echo $(INDENT)[$(notdir $(firstword $(CXX)))] Compiling $< for $(if $(DEBUG),Debug,Release) build
	@$(CXX) $(CXXFLAGS) $(if $(DEBUG),-g,-DNDEBUG) $(INCFLAGS) -c $< -o $@
	
obj/%.o:: %.C Makefile $(ROOT)/common.mk $(INCLUDE_DIRS) $(INCLUDES)
	@mkdir -p obj
	@echo $(INDENT)[$(notdir $(firstword $(CXX)))] Compiling $< for $(if $(DEBUG),Debug,Release) build
	@$(CXX) $(CXXFLAGS) $(if $(DEBUG),-g,-DNDEBUG) $(INCFLAGS) -c $< -o $@

$(SHARED_LIB_TARGETS):: $(OBJS) $(INCLUDE_DIRS) $(INCLUDES) Makefile $(ROOT)/common.mk
	@echo $(INDENT)[$(notdir $(firstword $(CXXLIB)))] Linking $@ for $(if $(DEBUG),Debug,Release) build
	@$(CXXLIB) $(CXXFLAGS) $(INCFLAGS) $(OBJS) -o $@ $(LIBFLAGS)

$(STATIC_LIB_TARGETS):: $(OBJS) $(INCLUDE_DIRS) $(INCLUDES) Makefile $(ROOT)/common.mk
	@echo $(INDENT)[ar] Linking $@ for $(if $(DEBUG),Debug,Release) build
	@ar rcs $@ $(OBJS)

$(OTHER_TARGETS):: $(OBJS) $(INCLUDE_DIRS) $(INCLUDES) Makefile $(ROOT)/common.mk
	@echo $(INDENT)[$(notdir $(firstword $(CXX)))] Linking $@ for $(if $(DEBUG),Debug,Release) build
	@$(CXX) $(CXXFLAGS) $(if $(DEBUG),-g,-DNDEBUG) $(INCFLAGS) $(OBJS) -o $@ $(LIBFLAGS)

$(RECURSIVE_TARGETS)::
	@for dir in $(DIRS); do \
	  echo "$(INDENT)[$@] Entering $$dir"; \
	  $(MAKE) -C $$dir $@ DEBUG=$(DEBUG); \
	done

$(ROOT)/Heap-Layers:
	@ echo $(INDENT)[git] Checking out Heap-Layers
	@rm -rf $(ROOT)/Heap-Layers
	@git clone https://github.com/emeryberger/Heap-Layers.git $(ROOT)/Heap-Layers

$(ROOT)/DieHard/src/include $(ROOT)/DieHard/src/include/math $(ROOT)/DieHard/src/include/rng $(ROOT)/DieHard/src/include/static $(ROOT)/DieHard/src/include/util:
	@echo $(INDENT)[git] Checking out DieHard
	@rm -rf $(ROOT)/DieHard
	@git clone https://github.com/emeryberger/DieHard.git $(ROOT)/DieHard
