#ifndef _SHUFFLEHEAP_H_
#define _SHUFFLEHEAP_H_

#include <cstdlib>
#include <cstring>

/**
 * Round a number up to multiple of another number
 * \param x The number to round
 * \param y The result will be a multiple of this parameter
 * \params x rounded up to a multiple of y
 */
constexpr size_t round_up(size_t x, size_t y) {
	return x % y == 0 ? x : x + (y - x % y);
}

#include "SizeHeap.hpp"
#include "HugeShuffleHeap.hpp"

enum {
	PageSize = 0x1000,
	
	RangeSize = 0x10000,	//< The range of addresses that should be covered by a block source
	ShuffleAhead = 128,		//< The number of elements in the freelist to shuffle
	HugeShuffleAhead = 8,	//< The number of elements in the huge object freelist to shuffle
	
	DataProt = PROT_READ | PROT_WRITE,			//< mmap Protection settings for a data heap
	DataFlags = MAP_PRIVATE | MAP_ANONYMOUS,	//< mmap Flags for a data heap
	
	CodeProt = PROT_READ | PROT_WRITE | PROT_EXEC,		//< mmap Protection settings for a code heap
	CodeFlags = MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT	//< mmap Flags for a code heap
};

/**
 * \brief The Shuffle Heap
 * The Shuffle Heap is a size-segregated heap that randomizes allocated memory at four levels:
 *   -# All allocations are satisfied from a freelist where the last \a ShuffleAhead freed objects are
 *      returned in random order using the Fisher-Yates shuffle
 *   -# The freelist is populated (maintaining a size of at least \a ShuffleAhead objects) from a
 *      \a HeapBlock. Heap blocks use a random walk to return object slots in some random order.
 *   -# Every allocation from a \a HeapBlock is satisfied from one of \a HeapBlock::LiveBlockCount
 *      blocks selected at random.
 *   -# Finally, heap blocks are allocated from the \a BlockSource, which uses a random walk to return
 *      blocks in a random order covering a size \a RangeSize range of memory addresses.
 *
 * \tparam Code If true, this heap will be mapped as executable, and in the lower 32 bits of memory if possible
 * \tparam SizeClasses A list of size classes for the heap
 */
template<bool Code, uint32_t (*rng)(), size_t... SizeClasses> struct ShuffleHeap;

/**
 * Specialize the ShuffleHeap template for the top level where no size classes remain.
 * When large object support is implemented, it should go into this level.
 */
template<bool Code, uint32_t (*rng)()>
struct ShuffleHeap<Code, rng> {
	// Generate flags and protection settings for code or data
	constexpr static const int Prot = Code ? CodeProt : DataProt;
	constexpr static const int Flags = Code ? CodeFlags : DataFlags;
	
	HugeShuffleHeap<Prot, Flags, HugeShuffleAhead, rng> hugeHeap;
	
	inline void* malloc(size_t sz) {
		return hugeHeap.malloc(sz);
	}
	
	inline void free(void* p) {
		hugeHeap.free(p);
	}
	
	inline size_t getSize(void* p) {
		return hugeHeap.getSize(p);
	}
};

/**
 * Handle one size class of the ShuffleHeap
 *
 * TODO: Size classes with identical BlockSize should share a single BlockSource
 */
template<bool Code, uint32_t (*rng)(), size_t SizeClass, size_t... Rest>
struct ShuffleHeap<Code, rng, SizeClass, Rest...> {
	// Make sure we can fit at least 16 objects on a Block (blocks will be one page up to SizeClass=256)
	constexpr static const size_t BlockSize = round_up(SizeClass*16, PageSize);
	
	// Generate flags and protection settings for code or data
	constexpr static const int Prot = Code ? CodeProt : DataProt;
	constexpr static const int Flags = Code ? CodeFlags : DataFlags;
	
	/// The size-specific shuffle heap for this size class
	SizeHeap<SizeClass, BlockSize, RangeSize, ShuffleAhead, Prot, Flags, rng> thisSize;
	
	/// The shuffle heap for the next size class up
	ShuffleHeap<Code, rng, Rest...> nextSize;
	
	/**
	 * Allocate memory of size \a sz
	 * \param sz The size of memory to allocate
	 * \returns A pointer to allocated memory, or NULL if something goes wrong
	 */
	inline void* malloc(size_t sz) {
		if(sz <= SizeClass) {
			// We're at the right size class, so allocate from the subheap
			return thisSize.next();
		} else {
			// This isn't the right size class, so continue up the chain
			return nextSize.malloc(sz);
		}
	}
	
	/**
	 * Free allocated memory
	 * \param p A pointer to the base of the allocation
	 */
	inline void free(void* p) {
		size_t sz = getSize(p);
		if(sz == SizeClass) {
			thisSize.free(p);
		} else {
			assert(sz == 0 || sz > SizeClass);
			nextSize.free(p);
		}
	}
	
	inline size_t getSize(void* p) {
		size_t sz = HeapBlock<BlockSize, SizeClass>::lookupSize(p);
		if(sz != 0) {
			return sz;
		} else {
			return nextSize.getSize(p);
		}
	}
};

#endif
