#ifndef RUNTIME_UTIL_H
#define RUNTIME_UTIL_H

#include <stdint.h>
#include <sys/mman.h>

#include "Arch.h"
#include "randomnumbergenerator.h"

#ifndef PAGESIZE
#define PAGESIZE 4096
#endif

#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif

#ifndef MAP_32BIT
#define MAP_32BIT 0
#endif

#if !defined(CODE_ALIGN)
#define CODE_ALIGN 128
#endif

#define ALIGN_DOWN(x, y) (void*)((uintptr_t)(x) - ((uintptr_t)(x) % (y)))
#define ALIGN_UP(x, y) ALIGN_DOWN(((uintptr_t)x + y - 1), y)

static void flush_icache(void* begin, size_t size) {
    _PPC(
        uintptr_t p = (uintptr_t)begin & ~15UL;
        for (size_t i = 0; i < size; i += 16) {
            asm("icbi 0,%0" : : "r"(p));
            p += 16;
        }
        asm("isync");
    )
}

#define TRAP _PPC((void*)0x0) _AnyX86((void*)0xCC)

static inline uint8_t getRandomByte() {
	static RandomNumberGenerator _rng;
	static uint8_t _randCount = 0;
	
	static union {
		uint8_t _rands[sizeof(int)];
		int _bigRand;
	};
	
	if(_randCount == sizeof(int)) {
		_bigRand = _rng.next();
		_randCount = sizeof(int);
	}
	
	uint8_t r = _rands[_randCount];
	_randCount++;
	return r;
}

#endif
