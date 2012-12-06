#ifndef RUNTIME_UTIL_H
#define RUNTIME_UTIL_H

#include <stdint.h>
#include <sys/mman.h>

#ifndef PAGESIZE
#define PAGESIZE 4096
#endif

#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif

#ifndef MAP_32BIT
#define MAP_32BIT 0
#endif


#if !defined(_XOPEN_SOURCE)
// Digging inside of ucontext_t is deprecated unless this macros is defined
#define _XOPEN_SOURCE
#endif

#include <ucontext.h>

#if defined(__APPLE__)

	#define GET_CONTEXT_IP(x) (((ucontext_t*)x)->uc_mcontext->__ss.__rip)
	#define SET_CONTEXT_IP(x, y) ((((ucontext_t*)x)->uc_mcontext->__ss.__rip) = (y))

#elif defined(__linux__)

	#define GET_CONTEXT_IP(x) (((ucontext_t*)x)->uc_mcontext.gregs[REG_RIP])
	#define SET_CONTEXT_IP(x, y) ((((ucontext_t*)x)->uc_mcontext.gregs[REG_RIP]) = (y))

#endif

#define ALIGN_DOWN(x, y) (void*)((uintptr_t)(x) - ((uintptr_t)(x) % (y)))
#define ALIGN_UP(x, y) ALIGN_DOWN(((uintptr_t)x + y - 1), y)

static void flush_icache(void* begin, size_t size) {
#if defined(PPC)
    uintptr_t p = (uintptr_t)begin & ~15UL;
    for (size_t i = 0; i < size; i += 16) {
        asm("icbi 0,%0" : : "r"(p));
		p += 16;
    }
    asm("isync");
#endif
}

#ifndef NDEBUG
#include <stdio.h>
#include <assert.h>
#define DEBUG(...) fprintf(stderr, "  "); fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n")
#else
#define DEBUG(_fmt, ...)
#endif

#define ABORT(...) fprintf(stderr, "ABORT %18s:%-3d: ", __FILE__, __LINE__); fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); abort()

#endif
