### About
Stabilizer is a compiler transformation and runtime library for dynamic memory 
layout randomization. Programs built with Stabilizer run with randomly-placed 
functions, stack frames, and heap objects. Functions and stack frames are moved 
repeatedly during execution. A random memory layout eliminates the effect of 
layout on performance, and repeated randomization leads to normally-distributed 
execution times. This makes it straightforward to use standard statistical tests 
for performance evaluation.

A more detailed description of Stabilizer is available in the 
[Paper](http://www.cs.umass.edu/~charlie/stabilizer.pdf), which will appear at
ASPLOS 2013 in March.

### Requirements
Stabilizer requires [LLVM 3.1](http://llvm.org/releases/download.html#3.1). 
Stabilizer runs on OSX and Linux, and supports x86, x86_64, and PowerPC.

Stabilizer requires LLVM 3.1. Follow the directions
[here](http://clang.llvm.org/get_started.html) to build LLVM 3.1 and the Clang
front-end. Stabilizer's build system assumes LLVM include files will be
accessible through your default include path.

By default, Stabilizer will use GCC and the 
[Dragonegg](http://dragonegg.llvm.org/) plugin to produce LLVM IR. Fortran 
programs can only be built with the `gcc` front end. Stabilizer is tested 
against GCC 4.6.2.

Stabilizer's compiler driver (`szc`) is written in Python.  It uses the 
`argparse` module, so a relatively modern version (>=2.7) is required.

### Building Stabilizer
```
$ git clone git://github.com/ccurtsinger/stabilizer.git stabilizer
$ make
```

By default, Stabilizer is build with debug output enabled.  Run 
`make clean release` to build the release version with asserts and debug output 
disabled.

### Using Stabilizer
Stabilizer includes the `szc` compiler driver, which builds programs using the 
Stabilizer compiler transformations.  `szc` mimics a `gcc` interface, and is 
compatible with C, C++ and Fortran inputs.

To compile a program in `foo.c` with Stabilizer, run:
```
$ szc -Rcode -Rstack -Rheap foo.c -o foo
```

The `-R` flags enable randomizations, and may be used in any combination.
Stabilizer uses `gcc` with the `dragonegg` plugin as its default front-end. To
use clang, pass `-frontend=clang` to `szc`.

The resulting executable is linked against with `libstabilizer.so` (or `.dylib` 
on OSX). Place this library somewhere in your system's dynamic library search
path or (preferably) add the Stabilizer base directory to your LD_LIBRARY_PATH
or DYLD_LIBRARY_PATH environment variable.
