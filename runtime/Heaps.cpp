//
//  Heaps.cpp
//  stabilizer2
//
//  Created by Charlie Curtsinger on 9/24/11.
//  Copyright 2011 University of Massachusetts. All rights reserved.
//

#include "Heaps.h"

#include "diehard.h"
#include "ansiwrapper.h"
#include "combineheap.h"
#include "randomnumbergenerator.h"
#include "realrandomvalue.h"
#include "largeheap.h"
#include "mmapwrapper.h"
#include "lockheap.h"
#include "oneheap.h"
#include "diehardheap.h"
#include "version.h"
#include "freelistheap.h"

#define FREE_LIST_SZ_CLASSES 16

enum { Numerator = 1, Denominator = 1 };

class Heap : public CombineHeap<DieHardHeap<Numerator, Denominator, 65536, false>, OneHeap<LargeHeap<MmapWrapper> > > {};
class HeapType : public ANSIWrapper<Heap> {};

inline static HeapType* getMetadataHeap(void) {
	static char buf[sizeof(HeapType)];
	static HeapType* _theMetadataHeap = new(buf) HeapType;
	return _theMetadataHeap;
}

inline static HeapType* getCodeHeap(void) {
	static char buf[sizeof(HeapType)];
	static HeapType* _theCodeHeap = new(buf) HeapType;
	return _theCodeHeap;
}

inline static HeapType* getDieHardHeap(void) {
	static char buf[sizeof(HeapType)];
	static HeapType* _theDieHardHeap = new(buf) HeapType;
	return _theDieHardHeap;
}

void* MD_malloc(size_t sz) {
	return getMetadataHeap()->malloc(sz);
}

void MD_free(void *p) {
	getMetadataHeap()->free(p);
}

void* Code_malloc(size_t sz) {
	return getCodeHeap()->malloc(sz);
}

void Code_free(void *p) {
	getCodeHeap()->free(p);
}

typedef struct free_list {
	struct free_list *next;
} free_list_t;

free_list_t *free_list[FREE_LIST_SZ_CLASSES];

size_t bsr(size_t x) {
	return sizeof(size_t)*8-__builtin_clzl(x)-1;
}

extern "C" {
	void* DH_malloc(size_t sz) {
		size_t l = bsr(sz);
		
		if(l > bsr(sizeof(free_list_t)) && l < FREE_LIST_SZ_CLASSES && free_list[l] != NULL) {
			void *p = (void*)free_list[l];
			free_list[l] = free_list[l]->next;
			//printf("allocating from cache\n");
			return p;
		}

		return getDieHardHeap()->malloc(sz);
	}

	void* DH_calloc(size_t n, size_t sz) {
		return getDieHardHeap()->calloc(n, sz);
	}

	void* DH_realloc(void *ptr, size_t sz) {
		return getDieHardHeap()->realloc(ptr, sz);
	}

	void DH_free(void *p) {
		size_t sz = getDieHardHeap()->getSize(p);
		size_t l = bsr(sz);
		
		if(l > bsr(sizeof(free_list_t)) && l < FREE_LIST_SZ_CLASSES) {
			free_list_t *e = (free_list_t*)p;
			e->next = free_list[l];
			free_list[l] = e;
			
			//printf("freeing to cache\n");
			
		} else {
			getDieHardHeap()->free(p);
		}
	}

	void DH_flush() {
		for(int i=0; i<FREE_LIST_SZ_CLASSES; i++) {
			free_list_t *c = free_list[i];
			while(c != NULL) {
				void *p = (void*)c;
				c = c->next;
				getDieHardHeap()->free(p);
			}
			free_list[i] = NULL;
		}
	}
}
