====================
ISPC Examples README
====================

This directory has a number of sample ispc programs.  Before building them
(on an system), install the appropriate ispc compiler binary into a
directory in your path.  Then, if you're running Windows, open the
"examples.sln" file and built from there.  For building under Linux/OSX,
there are makefiles in each directory that build the examples individually.

Almost all of them benchmark ispc implementations of the given computation
against regular serial C++ implementations, printing out a comparison of
the runtimes and the speedup delivered by ispc.  It may be instructive to
do a side-by-side diff of the C++ and ispc implementations of these
algorithms to learn more about wirting ispc code.


AOBench
=======

This is an ISPC implementation of the "AO bench" benchmark
(http://syoyo.wordpress.com/2009/01/26/ao-bench-is-evolving/).  The command
line arguments are:

ao (num iterations) (x res) (yres)

It executes the program for the given number of iterations, rendering an
(xres x yres) image each time and measuring the computation time with both
serial and ispc implementations.


AOBench_Instrumented
====================

This version of AO Bench is compiled with the --instrument ispc compiler
flag.  This causes the compiler to emit calls to a (user-supplied)
ISPCInstrument() function at interesting places in the compiled code.  An
example implementation of this function that counts the number of times the
callback is made and records some statistics about control flow coherence
is provided in the instrument.cpp file.


Deferred
========

This example shows an extensive example of using ispc for efficient
deferred shading of scenes with thousands of lights; it's an implementation
of the algorithm that Johan Andersson described at SIGGRAPH 2009,
implemented by Andrew Lauritzen and Jefferson Montgomery.  The basic idea
is that a pre-rendered G-buffer is partitioned into tiles, and in each
tile, the set of lights that contribute to the tile is first computed.
Then, the pixels in the tile are then shaded using just those light
sources. (See slides 19-29 of
http://s09.idav.ucdavis.edu/talks/04-JAndersson-ParallelFrostbite-Siggraph09.pdf
for more details on the algorithm.)

This directory includes two implementations of the algorithm:

- An ispc implementation that first does a static partitioning of the
  screen into tiles to parallelize across the CPU cores.  Within each tile
  ispc kernels provide highly efficient implementations of the light
  culling and shading calculations.
- A "best practices" serial C++ implementation.  This implementation does a
  dynamic partitioning of the screen, refining tiles with significant Z
  depth complexity (these tiles often have a large number of lights that
  affect them).  Within each final tile, the pixels are shaded using
  regular C++ code.


GMRES
=====

An implementation of the generalized minimal residual method for solving
sparse matrix equations.
(http://en.wikipedia.org/wiki/Generalized_minimal_residual_method)


Mandelbrot
==========

Mandelbrot set generation.  This example is extensively documented at the
https://ispc.github.io/example.html page.


Mandelbrot_tasks
================

Implementation of Mandelbrot set generation that also parallelizes across
cores using tasks.  Under Windows, a simple task system built on
Microsoft's Concurrency Runtime is used (see tasks_concrt.cpp).  On OSX, a
task system based on Grand Central Dispatch is used (tasks_gcd.cpp), and on
Linux, a pthreads-based task system is used (tasks_pthreads.cpp).  When
using tasks with ispc, no task system is mandated; the user is free to plug
in any task system they want, for ease of interoperating with existing task
systems.


Noise
=====

This example has an implementation of Ken Perlin's procedural "noise"
function, as described in his 2002 "Improving Noise" SIGGRAPH paper.


Options
=======

This program implements both the Black-Scholes and Binomial options pricing
models in both ispc and regular serial C++ code.


Perfbench
=========

This runs a number of microbenchmarks to measure system performance and
code generation quality.


RT
==

This is a simple ray tracer; it reads in camera parameters and a bounding
volume hierarchy and renders the scene from the given viewpoint.  The
command line arguments are:

rt <scene name base>

Where <scene base name> is one of "cornell", "teapot", or "sponza".

The implementation originally derives from the bounding volume hierarchy
and triangle intersection code from pbrt; see the pbrt source code and/or
"Physically Based Rendering" book for more about the basic algorithmic
details.


Simple
======

This is a simple "hello world" type program that shows a ~10 line
application program calling out to a ~5 line ispc program to do a simple
computation.

Sort
====
This is a bucket sort of 32 bit unsigned integers.
By default 1000000 random elements get sorted.
Call ./sort N in order to sort N elements instead.

Volume
======

Ray-marching volume rendering, with single scattering lighting model.  To
run it, specify a camera parameter file and a volume density file, e.g.:

volume camera.dat density_highres.vol

(See, e.g. Chapters 11 and 16 of "Physically Based Rendering" for
information about the algorithm implemented here.)  The volume data set
included here was generated by the example implementation of the "Wavelet
Turbulence for Fluid Simulation" SIGGRAPH 2008 paper by Kim et
al. (http://www.cs.cornell.edu/~tedkim/WTURB/)

SGEMM
=====
This program uses ISPC to implement different versions of matrix multiply with
varying levels of optimization to explore syntax and implementation options enabled by ISPC.
Most of the optimized examples are able to achieve 85-90% peak architectural flops using
AVX2 compilation target, yet retain elegantly simple code to understand and
maintain. The command line arguments are:

sgemm (optional)[num iterations] (optional)[[Matrix A Rows] [Matrix A Columns/Matrix B Rows] [Matrix B Columns]]

Point Transform using ctypes
============================
This example demonstrates how to use ctypes to call a single ISPC function that takes three different types of inputs:

* Float arrays (the x and y coordinates of points)
* A custom structure (the Transform struct with scaling, translation, and rotation parameters)
* A constant value (the strength parameter that controls transformation intensity)

The example includes:

An ISPC implementation that applies geometric transformations to points:

* Scaling on both x and y axes
* Rotation around the origin
* Translation with a configurable strength factor

A Python wrapper that:

* Defines a matching ctypes structure for the ISPC struct
* Sets up the proper function signature
* Handles conversion between NumPy arrays and C pointers
* Passes the structure by reference using ctypes.byref()

A NumPy reference implementation to verify correctness and compare performance.

After building the example, run the Python script to transform points and see the performance comparison.

Point Transform using nanobind
==============================

This example demonstrates how to use nanobind to efficiently wrap an ISPC function that applies geometric transformations to 2D points. The example shows how to integrate high-performance ISPC vectorized code with Python's NumPy using nanobind bindings.
The example includes:
An ISPC implementation that applies geometric transformations to points:

* Scaling on both x and y axes
* Rotation around the origin
* Translation with a configurable strength factor

A C++ nanobind wrapper that:

* Exposes the ISPC Transform struct as a native Python class
* Creates proper bindings for the transformation function
* Handles conversion between NumPy arrays and C arrays automatically
* Provides efficient direct buffer access for pre-allocated arrays

A Python test script that:

* Creates and uses the Transform object
* Allocates NumPy arrays for input and output data
* Runs benchmarks comparing ISPC and NumPy implementations
* Verifies the correctness of results

Advantages over ctypes:

* Type Safety: Nanobind provides compile-time type checking, unlike ctypes which is completely dynamic.
* Better Performance: Nanobind has optimized data conversion paths, especially for NumPy arrays.
* Memory Management: Nanobind handles memory management automatically and safely, preventing memory leaks.
* Native Python Integration: The Transform struct is exposed as a proper Python class with attributes, making it more intuitive and Pythonic to use.
* Better Error Handling: C++ exceptions are properly translated to Python exceptions, with meaningful error messages.
* Simplified Array Handling: No need to manually extract pointers from NumPy arrays or manage strides - nanobind handles this transparently.

Attention
=========

This example demonstrates efficient implementation of the single-head attention mechanism commonly used in transformer-based neural networks. It showcases advanced ISPC techniques including:

* Multiple matrix multiplication implementations (GOTO-based and tiled)
* Memory pool management for efficient intermediate tensor storage
* Task-based parallelism for scaling across CPU cores
* Softmax implementation with optimized memory access patterns

The example includes:

* ISPC implementations of attention with two different algorithms:
  - GOTO-matmul: Uses the GEMM implementation optimized with blocking and vectorization
  - Tiled-matmul: Uses task-based parallelism with tiled execution for better cache locality

* A Python benchmark using nanobind that:
  - Compares performance of both ISPC implementations against PyTorch
  - Validates numerical correctness of the results
  - Reports detailed performance metrics (GFLOPS, speedup ratios)
  - Analyzes execution time variability
