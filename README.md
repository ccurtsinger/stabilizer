### About
Stabilizer is a compiler transformation and runtime library for dynamic memory layout randomization. Programs built with Stabilizer run with randomly-placed functions, stack frames, and heap objects. Functions and stack frames are moved repeatedly during execution. A random memory layout eliminates the effect of layout on performance, and repeated randomization leads to normally-distributed execution times. This makes it straightforward to use standard statistical tests for performance evaluation.

A more detailed description of Stabilizer is available in the [Tech Report](https://web.cs.umass.edu/publication/details.php?id=2248).  Some implementation details have changed since the publication of this tech report.  An updated paper will appear at ASPLOS 2013 in March.

### Requirements
Stabilizer requires [LLVM 3.1](http://llvm.org/releases/download.html#3.1). Stabilizer is developed for OSX and Linux on the x86 and x86_64 architectures, and has limited support for LLVM's PowerPC backend.

### Building Stabilizer
Before building Stabilizer, you'll need to check out and build [LLVM 3.1](http://llvm.org/releases/download.html#3.1) and the `clang` compiler front-end.

```
$ git clone git://github.com/ccurtsinger/stabilizer.git stabilizer
$ make
```

### Using Stabilizer
Stabilizer includes the `szc` compiler driver, which builds programs using the Stabilizer compiler transformations.  `szc` mimics a `gcc` interface, and is compatible with C, C++ and Fortran files.

To compile a program in `foo.c` with Stabilizer, run:
```
$ szc -stabilizer=<path to stabilizer> -coderand -stackrand -heaprand main.c -o foo
```

The `-coderand`, `-stackrand`, and `-heaprand` flags control the three randomizations, and may be used in any combination.
