
SHLIB_SUFFIX = dylib
CFLAGS = -D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS
SZCFLAGS = -osx
LD_PATH_VAR = DYLD_LIBRARY_PATH
CXXLIB = $(CXX) -shared -fPIC -compatibility_version 1 -current_version 1 -Wl,-flat_namespace,-undefined,suppress -dynamiclib
