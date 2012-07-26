//
//  util.h
//  stabilizer2
//
//  Created by Charlie Curtsinger on 9/13/11.
//  Copyright 2011 University of Massachusetts. All rights reserved.
//

#ifndef stabilizer2_util_h
#define stabilizer2_util_h

#ifndef PAGESIZE
#define PAGESIZE 4096
#endif

#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif

#ifndef MAP_32BIT
#define MAP_32BIT 0
#endif

#if defined(__APPLE__)

	#define GET_CONTEXT_IP(x) (((ucontext_t*)x)->uc_mcontext->__ss.__rip)
	#define SET_CONTEXT_IP(x, y) ((((ucontext_t*)x)->uc_mcontext->__ss.__rip) = (y))

#elif defined(__linux__)

	#define GET_CONTEXT_IP(x) (((ucontext_t*)x)->uc_mcontext.gregs[REG_RIP])
	#define SET_CONTEXT_IP(x, y) ((((ucontext_t*)x)->uc_mcontext.gregs[REG_RIP]) = (y))

#endif

#define ALIGN_DOWN(x, y) (void*)((uintptr_t)(x) - ((uintptr_t)(x) % (y)))
#define ALIGN_UP(x, y) ALIGN_DOWN(((uintptr_t)x + y - 1), y)

#if !defined(NDEBUG) && !defined(SOCLIB)
#include <stdio.h>
#include <assert.h>
#define DEBUG(...) fprintf(stderr, "  "); fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n")
#else
#define DEBUG(_fmt, ...)
#endif

#define ABORT(...) fprintf(stderr, "ABORT %18s:%-3d: ", __FILE__, __LINE__); fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); abort()

#endif
