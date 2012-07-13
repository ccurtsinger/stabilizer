#ifndef _BLOCKSOURCE_H_
#define _BLOCKSOURCE_H_

#include <cassert>
#include <cerrno>
#include <cstdlib>
#include <cstdio>

#include <sys/mman.h>

#include "Coprimes.hpp"

#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif

#ifndef MAP_32BIT
#define MAP_32BIT 0
#endif

template<size_t BlockSize, size_t BlockCount, int Prot, int Flags, uint32_t (*rng)()>
struct BlockSource {
	intptr_t chunk;
	size_t increment;
	size_t index;
	size_t allocated;
	
	BlockSource() {
		chunk = (intptr_t)mmap(NULL, BlockSize * (BlockCount+1), Prot, Flags, -1, 0);
		
		if((void*)chunk == MAP_FAILED) {
			perror("BlockSource mmap");
			exit(2);
		}
		
		// Shift up to ensure all blocks are BlockSize aligned
		if(chunk % BlockSize != 0) {
			chunk += BlockSize - (chunk % BlockSize);
		}

		increment = Coprimes<BlockCount, BlockCount>::get(rng() % BlockCount);
		index = rng() % BlockCount;
		allocated = 0;
	}
	
	void* next() {
		if(allocated == BlockCount) {
			return NULL;
		}
		
		void* p = (void*)(chunk + BlockSize * index);
		
		index = (index + increment) % BlockCount;
		allocated++;
		
		return p;
	}
};

#endif
