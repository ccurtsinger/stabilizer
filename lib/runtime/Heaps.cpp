//
//  Heaps.cpp
//  stabilizer2
//
//  Created by Charlie Curtsinger on 9/24/11.
//  Copyright 2011 University of Massachusetts. All rights reserved.
//

#include "Util.h"
#include "Heaps.h"

#include "shuffleheap/ansiwrapper.h"
#include "shuffleheap/ShuffleHeap.hpp"

#include "shuffleheap/MWC.hpp"
#include "shuffleheap/RealRandomValue.hpp"

#ifndef NDEBUG
#include <map>
using namespace std;
map<void*, bool> heapmap;
#endif

uint32_t rng() {
	static MWC rng(RealRandomValue::value(), RealRandomValue::value());
	return rng.next();
}

HL::ANSIWrapper<ShuffleHeap<false, rng, 32, 64, 128, 256, 512, 1024, 2048, 4096>> metadataHeap;
HL::ANSIWrapper<ShuffleHeap<true, rng, 32, 64, 128, 256, 512, 1024, 2048, 4096>> codeHeap;
HL::ANSIWrapper<ShuffleHeap<false, rng, 32, 64, 128, 256, 512, 1024, 2048, 4096>> mainHeap;

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
