#ifndef _HUGESHUFFLEHEAP_H_
#define _HUGESHUFFLEHEAP_H_

#include <cassert>

#include <stdint.h>
#include <sys/mman.h>

#include "ShuffleFreelist.hpp"

enum {
	HugeMagic = 0xDEADBEEF,
	MinHugeSize = 0x1000
};

struct HugeHeader {
	uint32_t magic;
	uint32_t size;
	HugeHeader* next;
	uint8_t pad[48];
	
	HugeHeader(size_t size, HugeHeader* next) {
		this->magic = HugeMagic;
		this->size = size;
		this->next = next;
	}
	
	inline void* operator new(size_t sz, void* p) {
		return p;
	}
	
	inline static HugeHeader* fromUsableBase(void* p) {
		HugeHeader* h = &((HugeHeader*)p)[-1];
		assert(h->magic == HugeMagic && "Invalid Huge Object Header!");
		return h;
	}
	
	void* getUsableBase() {
		return &this[1];
	}
};

template<int Prot, int Flags, size_t ShuffleAhead, uint32_t (*rng)()> struct HugeShuffleHeap {
	HugeHeader* freelist = NULL;
	
	inline void* getMemory(size_t sz) {
		void* p = mmap(NULL, sz, Prot, Flags, -1, 0);
		if(p == MAP_FAILED) {
			perror("HugeShuffleHeap mmap");
			exit(2);
		}
		return p;
	}
	
	inline void* malloc(size_t sz) {
		// First fit scan through the freelist
		HugeHeader* prev = NULL;
		HugeHeader* current = freelist;
		
		while(current != NULL) {
			if(current->size >= sz) {
				if(prev == NULL) {
					freelist = current->next;
				} else {
					prev->next = current->next;
				}
				return current->getUsableBase();
			}
			
			prev = current;
			current = current->next;
		}
		
		size_t allocation_size = round_up(sz + sizeof(HugeHeader), MinHugeSize);
		HugeHeader* obj = new(getMemory(allocation_size)) HugeHeader(sz, NULL);
		return obj->getUsableBase();
	}
	
	inline void free(void* p) {
		HugeHeader* obj = HugeHeader::fromUsableBase(p);
		freelist = new(obj) HugeHeader(obj->size, freelist);
	}
	
	inline size_t getSize(void* p) {
		HugeHeader* obj = HugeHeader::fromUsableBase(p);
		return obj->size;
	}
};

#endif
