#ifndef _SHUFFLEFREELIST_H_
#define _SHUFFLEFREELIST_H_

#include <cassert>
#include <cstdlib>
#include <new>

enum {
	FreeMagic = 0xBEEFCA75
};

struct FreelistNode {
	struct FreelistNode* next;
	size_t magic;
	
	FreelistNode(FreelistNode* next) {
		this->next = next;
		assert(this->magic != FreeMagic && "Possible double free error!");
		this->magic = FreeMagic;
	}
	
	inline void* operator new(size_t sz, void* p) {
		return p;
	}
	
	void wipeMagic() {
		magic = 0;
	}
};

template<size_t ShuffleAhead, uint32_t (*rng)()> struct ShuffleFreelist {
	FreelistNode* shuffled[ShuffleAhead];
	size_t shuffledCount = 0;
	
	FreelistNode* overflow = NULL;
	size_t overflowCount = 0;
	
	inline void* nextOverflow() {
		if(overflow == NULL) {
			return NULL;
		}
		
		// Clear the magic numbers in the overflow node to mark it as allocated
		overflow->wipeMagic();
		void* p = (void*)overflow;
		overflowCount--;
		overflow = overflow->next;
		
		return p;
	}
	
	inline void* nextShuffled() {
		if(shuffledCount == 0) {
			return NULL;
		}
		
		FreelistNode* p = shuffled[shuffledCount-1];
		p->wipeMagic();
		
		shuffledCount--;
		refillShuffled();
		
		return p;
	}
	
	inline void refillShuffled() {
		while(needsMore() && overflowCount > 0) {
			void* p = nextOverflow();
			free(p);
		}
	}
	
	inline bool needsMore() {
		return shuffledCount < ShuffleAhead;
	}
	
	inline void* next() {
		void* p = nextShuffled();
		
		if(p == NULL) {
			p = nextOverflow();
		}
		
		return p;
	}
	
	inline void free(void* p) {
		// If nothing is freed, just put it in the buffer
		if(shuffledCount == 0) {
			shuffled[0] = new(p) FreelistNode(NULL);
			shuffledCount++;
			return;
		}
		
		// If the shuffled buffer is full, put the object on the overflow list
		if(shuffledCount == ShuffleAhead) {
			overflow = new(p) FreelistNode(overflow);
			overflowCount++;
			return;
		}
		
		// Otherwise, there's space in the shuffle buffer, so insert it with the
		// inside-out Fisher-Yates shuffle
		size_t index = rng() % (shuffledCount + 1);
		shuffled[shuffledCount] = shuffled[index];
		shuffled[index] = new(p) FreelistNode(NULL);
		shuffledCount++;
	}
};

#endif
