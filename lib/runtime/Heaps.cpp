//
//  Heaps.cpp
//  stabilizer2
//
//  Created by Charlie Curtsinger on 9/24/11.
//  Copyright 2011 University of Massachusetts. All rights reserved.
//

#include "Util.h"
#include "Heaps.h"

#include "heaplayers.h"
#include "combineheap.h"
#include "diehard.h"
#include "randomnumbergenerator.h"
#include "realrandomvalue.h"
#include "largeheap.h"
#include "diehardheap.h"

#undef throw
#undef try

enum { Numerator = 8, Denominator = 7 };
class LargeDataHeap : public OneHeap<LargeHeap<MmapWrapper> > {};
class LargeCodeHeap : public OneHeap<LargeHeap<MmapWrapper> > {};
typedef ANSIWrapper<CombineHeap<DieHardHeap<Numerator, Denominator, 65536, true, false>, LargeDataHeap> > DataHeapType;
typedef ANSIWrapper<CombineHeap<DieHardHeap<Numerator, Denominator, 65536, true, false>, LargeCodeHeap> > CodeHeapType;

DataHeapType metadataHeap;
DataHeapType mainHeap;
CodeHeapType codeHeap;

void* MD_malloc(size_t sz) {
	return metadataHeap.malloc(sz);
}

void MD_free(void *p) {
	metadataHeap.free(p);
}

void* Code_malloc(size_t sz) {
	return codeHeap.malloc(sz);
}

void Code_free(void *p) {
	codeHeap.free(p);
}

extern "C" {
	void* DH_malloc(size_t sz) {
		return mainHeap.malloc(sz);
	}

	void* DH_calloc(size_t n, size_t sz) {
		return mainHeap.calloc(n, sz);
	}

	void* DH_realloc(void *p, size_t sz) {
		return mainHeap.realloc(p, sz);
	}

	void DH_free(void *p) {
		mainHeap.free(p);
	}
}
