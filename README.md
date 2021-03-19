## Stabilizer: Statistically Sound Performance Evaluation
[Charlie Curtsinger](https://curtsinger.cs.grinnell.edu/) and [Emery D. Berger](https://www.emeryberger.com)
University of Massachusetts Amherst

### Abstract

Researchers and software developers require effective performance
evaluation. Researchers must evaluate optimizations or measure
overhead. Software developers use automatic performance regression tests to discover when changes improve or degrade performance.
The standard methodology is to compare execution times before and
after applying changes.

Unfortunately, modern architectural features make this approach
unsound. Statistically sound evaluation requires multiple samples
to test whether one can or cannot (with high confidence) reject the
null hypothesis that results are the same before and after. However,
caches and branch predictors make performance dependent on
machine-specific parameters and the exact layout of code, stack
frames, and heap objects. A single binary constitutes just one sample
from the space of program layouts, regardless of the number of runs.
Since compiler optimizations and code changes also alter layout, it
is currently impossible to distinguish the impact of an optimization
from that of its layout effects.

**Stabilizer** is a system that enables the use of
the powerful statistical techniques required for sound performance
evaluation on modern architectures. Stabilizer forces executions
to sample the space of memory configurations by repeatedly rerandomizing layouts of code, stack, and heap objects at runtime.
STABILIZER thus makes it possible to control for layout effects.
Re-randomization also ensures that layout effects follow a Gaussian
distribution, enabling the use of statistical tests like ANOVA. We
demonstrate Stabilizer's’s efficiency (< 7% median overhead) and
its effectiveness by evaluating the impact of LLVM’s optimizations
on the SPEC CPU2006 benchmark suite. We find that, while `-O2`
has a significant impact relative to `-O1`, the performance impact of
`-O3` over `-O2` optimizations is indistinguishable from random noise.

A full description of Stabilizer is available in the 
[technical paper](http://www.cs.umass.edu/~emery/pubs/stabilizer-asplos13.pdf), which appeared at
ASPLOS 2013.

See also this [nice blog post](https://fgiesen.wordpress.com/2017/09/02/papers-i-like-part-5/) about this research.

### Building Requirements

_NOTE: This project is no longer being actively maintained, and only works on quite old versions of LLVM._

Stabilizer requires [LLVM 3.1](http://llvm.org/releases/download.html#3.1). 
Stabilizer runs on OSX and Linux, and supports x86, x86_64, and PowerPC.

Stabilizer requires LLVM 3.1. Follow the directions
[here](http://clang.llvm.org/get_started.html) to build LLVM 3.1 and the Clang
front-end. Stabilizer's build system assumes LLVM include files will be
accessible through your default include path.

By default, Stabilizer will use GCC and the 
[Dragonegg](http://dragonegg.llvm.org/) plugin to produce LLVM IR. Fortran 
programs can only be built with the GCC front end. Stabilizer is tested 
against GCC version 4.6.2.

Stabilizer's compiler driver `szc` is written in Python.  It uses the 
`argparse` module, so a relatively modern version of Python (>=2.7) is required.

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
Stabilizer compiler transformations.  `szc` passes on common GCC flags, and is 
compatible with C, C++ and Fortran inputs.

To compile a program in `foo.c` with Stabilizer, run:
```
$ szc -Rcode -Rstack -Rheap foo.c -o foo
```

The `-R` flags enable randomizations, and may be used in any combination.
Stabilizer uses GCC with the Dragonegg plugin as its default front-end. To
use clang, pass `-frontend=clang` to `szc`.

The resulting executable is linked against with `libstabilizer.so` (or `.dylib` 
on OSX). Place this library somewhere in your system's dynamic library search
path or (preferably) add the Stabilizer base directory to your `LD_LIBRARY_PATH`
or `DYLD_LIBRARY_PATH` environment variable.

### SPEC CPU2006
The `szchi.cfg` and `szclo.cfg` config files can be installed in a SPEC CPU2006
config directory to build and run benchmarks with Stabilizer. The szchi config 
`-O2` for base and `-O3` for peak tuning, and szclo uses `-O0` and `-O1`.

The `run.py` and `process.py` scripts were used to drive experiments and
collect results. The run script accepts optimization levels, benchmarks to
enable (or disable with a "-" prefix), a number of runs, and build 
configurations in any order.  For example:

```
$ ./run.py 10 bzip2 code code.stack code.heap.stack
```
This will run the `bzip2` benchmark 10 times in each of three randomization
configurations. The `runspec` tool must be in your path, so `cd` to your SPEC
installation and `sourceh shrc` first.

```
$ ./run.py 10 -astar code link O2 O3
```
This will run every benchmark except `astar` 10 times with link randomization
at `-O2` and `-O3` optimization levels.

Be warned: there is no easy way to distinguish `O2` and `O0` results after the
fact: both are marked as "base" tuning.  Keep these results in separate 
directories.

The process script reads `.rsf` files from SPEC and provides some summary
statistics, or collects results in an easy-to-process format.

```
$ ./process.py $SPEC/result/*.rsf
```
This will print average runtimes for each benchmark in each configuration and
tuning level for the runs in your SPEC results directory.

Pass the `-trim` flag to remove the highest and lowest runtimes before computing 
the average.

The `-norm` flag tests the results for normality using the Shapiro-Wilk test.

The `-all` flag dumps all results to console, suitable for pasting into a
spreadsheet or CSV file.
