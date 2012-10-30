#ifndef _SIZEHEAP_H_
#define _SIZEHEAP_H_

#include <cassert>
#include <cstdlib>

#include "HeapBlock.hpp"
#include "ShuffleFreelist.hpp"
#include "BlockSource.hpp"

constexpr size_t max(size_t x, size_t y) {
	return x > y ? x : y;
}

template<size_t SizeClass, size_t BlockSize, size_t RangeSize, size_t ShuffleAhead, int Prot, int Flags, uint32_t (*rng)()> struct SizeHeap {
	// Make sure the BlockSource returns blocks from a range spanning RangeSize
	constexpr static const size_t BlockCount = max(RangeSize / BlockSize, 8);
	
	// Get objects from eight blocks at a time
	constexpr static const size_t LiveBlockCount = 4;
	
	BlockSource<BlockSize, BlockCount, Prot, Flags, rng> source;
	HeapBlock<BlockSize, SizeClass>* blocks[LiveBlockCount];
	ShuffleFreelist<ShuffleAhead, rng> freelist;
	
	static_assert(SizeClass >= sizeof(FreelistNode), "Size class is too small to hold freelist entry!");
	
	inline void fillFreelist() {
		while(freelist.needsMore()) {
			freelist.free(nextFromBlock());
		}
	}
	
	void* next() {
		fillFreelist();
		void* p = freelist.next();
		fillFreelist();
		assert(p != NULL && "The Freelist is empty.  Something has gone wrong!");
		return p;
	}
	
	void free(void* p) {
		#ifndef NDEBUG
		size_t sz = HeapBlock<BlockSize, SizeClass>::lookupSize(p);
		assert(sz == SizeClass && "Freeing object to the wrong SizeHeap!");
		#endif
		
		freelist.free(p);
	}
	
	void* nextFromBlock() {
		void* p = NULL;
		
		size_t index = rng() % LiveBlockCount;
		
		// Get an object from the block, if there is one
		if(blocks[index] != NULL) {
			p = blocks[index]->next();
		}
		
		// Block was NULL or empty
		if(p == NULL) {
			// Get memory for a new block from the blocksource
			void* block_p = source.next();
			
			// The blocksource must be empty. Refresh
			if(block_p == NULL) {
				source = BlockSource<BlockSize, BlockCount, Prot, Flags, rng>();
				block_p = source.next();
				assert(block_p != NULL && "Brand new BlockSource is empty!");
			}
			
			// Get the new block
			blocks[index] = new(block_p) HeapBlock<BlockSize, SizeClass>(rng);
			
			p = blocks[index]->next();
			assert(p != NULL && "Brand new HeapBlock is empty!");
		}
		
		return p;
	}
};

#endif
