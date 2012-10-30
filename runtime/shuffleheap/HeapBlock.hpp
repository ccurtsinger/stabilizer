#ifndef _HEAPBLOCK_H_
#define _HEAPBLOCK_H_

#include <cassert>
#include <cstdlib>
#include <stdint.h>
#include <new>

#include "Coprimes.hpp"

enum {
	BlockMagic = 0xD00FCA75
};

template<size_t BlockSize, size_t SizeClass> struct HeapBlock {
	constexpr static const size_t count = BlockSize / SizeClass;
	
	uint32_t magic;
	uint32_t sz;
	uint32_t increment;
	uint32_t index;
	uint32_t allocated;
	
	/**
	 * Initialize a new HeapBlock
	 * \param rng A random number generator that should be used to seed the HeapBlock's random walk
	 */
	HeapBlock(uint32_t (*rng)()) {
		magic = BlockMagic;
		sz = SizeClass;
		increment = Coprimes<count, count>::get(rng() % count);
		index = rng() % count;
		allocated = 0;
		
		preventHeaderOverlap();
	}
	
	/**
	 * All HeapBlock instances should be constructed using placement new.
	 * This operator checks the alignment of the given pointer
	 */
	inline void* operator new(size_t s, void* p) {
		assert(p != NULL && "HeapBlock is being initialized at NULL!");
		assert((intptr_t)p % BlockSize == 0 && "HeapBlock allocation pointer is not BlockSize aligned!");
		assert((intptr_t)p % SizeClass == 0 && "HeapBlock allocation pointer is not SizeClass aligned!");
		return p;
	}
	
	/**
	 * Find the size of an allocated object by locating its HeapBlock header
	 * \param p A pointer contained in the HeapBlock we're searching for
	 * \returns The size of the object, or zero if no header is found
	 */
	inline static size_t lookupSize(void* p) {
		intptr_t q = (intptr_t)p;
		auto b = (HeapBlock<BlockSize, 1>*)(q - q % BlockSize);
		
		if(b->magic == BlockMagic) {
			return b->sz;
		} else {
			return 0;
		}
	}
	
	/**
	 * Check if the current index overlaps with the HeapBlock header and
	 * increment past it if necessary
	 */
	inline void preventHeaderOverlap() {
		while(index * SizeClass < sizeof(HeapBlock<BlockSize, SizeClass>)) {
			index = (index + increment) % count;
			allocated++;
		}
	}
	
	/**
	 * Get the next available object from this HeapBlock
	 * \returns A pointer to the next available object, or NULL if the HeapBlock is full
	 */
	inline void* next() {
		if(allocated >= count) {
			return NULL;
		}
		
		void* p = (void*)((intptr_t)this + index * SizeClass);
		
		index = (index + increment) % count;
		allocated++;
		
		preventHeaderOverlap();
		
		assert((intptr_t)p > (intptr_t)this + (intptr_t)sizeof(HeapBlock<BlockSize, SizeClass>)
			&& "Allocated object overlaps HeapBlock header!");
		assert(lookupSize(p) == SizeClass && "Allocated object returns incorrect size lookup!");
		
		return p;
	}
	
private:
	/**
	 * Prevent accidental use of the non-placement new operator
	 */
	inline void* operator new(size_t sz) {
		return NULL;
	}
};

#endif
