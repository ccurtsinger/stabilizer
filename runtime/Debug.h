#if !defined(RUNTIME_DEBUG_H)
#define RUNTIME_DEBUG_H

void panic();

#if !defined(NDEBUG)
#include <stdio.h>
#include <assert.h>
    #define DEBUG(...) fprintf(stderr, " [%s:%d] ", __FILE__, __LINE__); fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n")
#else
    #define DEBUG(_fmt, ...)
#endif

#define ABORT(...) fprintf(stderr, " [%s:%d]  ABORT: ", __FILE__, __LINE__); fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); panic(); abort()

#endif
