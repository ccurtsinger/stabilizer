### About
Stabilizer is a compiler transformation and runtime library for dynamic memory layout randomization. Programs built with Stabilizer run with randomly-placed functions, stack frames, heap objects, and globals. Functions and stack frames are moved repeatedly during execution. A random memory layout eliminates the effect of layout on performance, and repeated randomization leads to normally-distributed execution times. This makes it straightforward to use standard statistical tests for performance evaluation.

A more detailed description of Stabilizer is available in the [Tech Report](https://web.cs.umass.edu/publication/details.php?id=2248).

### Requirements
Stabilizer requires [LLVM 2.9](href="http://llvm.org/releases/download.html#2.9). Either front-end for LLVM ([llvm-gcc](http://llvm.org/releases/download.html#2.9) or [clang](http://clang.llvm.org)) will work with Stabilizer. Stabilizer is developed for OSX and Linux on the x86_64 architecture, and has limited support for LLVM's PowerPC backend.

### Building Stabilizer
Before building Stabilizer, you'll need to check out and build [LLVM 2.9](http://llvm.org/releases/download.html#2.9) and one of the compiler front-ends. The `AutoRegen.sh` script will ask for the source and build directories for LLVM.

```
$ git clone git://github.com/ccurtsinger/stabilizer.git stabilizer
$ cd stabilizer/autoconf
$ ./AutoRegen.sh
$ cd ..
$ ./configure
$ make all install
```

Stabilizer uses [DieHard](http://www.diehard-software.org/) for random memory allocation. DieHard makes extensive use of template metaprogramming, so building Stabilizer for the first time can take a few minutes with slower compilers.

### Using Stabilizer
Building a program with Stabilizer requires five steps:
1. Compile source file to LLVM bytecode
2. Link bytecode files with `llvm-link`
3. Transform the bytecode with the Stabilizer `opt` pass
4. Generate a .o file with `llc`
5. Link the .o file with the Stabilizer runtime library

The following commands build `main.c` with Stabilizer:
```
$ clang -emit-llvm -c main.c -o main.bc
$ opt --load=LLVMStabilizer.so main.bc -o main.stabilizer.bc \
  -stabilize -stabilize-code -stabilize-stack \
  -stabilize-heap -stabilize-globals
$ llc -relocation-model=pic -disable-fp-elim -o main.o \
  main.stabilizer.bc
$ clang -o main main.o -lStabilizer -lstdc++
```
