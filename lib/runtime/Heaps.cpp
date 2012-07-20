//
//  Heaps.cpp
//  stabilizer2
//
//  Created by Charlie Curtsinger on 9/24/11.
//  Copyright 2011 University of Massachusetts. All rights reserved.
//

#include "Util.h"
#include "Heaps.h"
#include "TLSFLayer.hpp"
#include "shuffleheap.h"
#include "largeheap.h"
#include "combineheap.h"
#include "diehardheap.h"
#include "heaplayers.h"

#include <new>

#include <sys/mman.h>
#include <stdio.h>
#include <stdint.h>

using namespace std;

enum {
	CodeProt = PROT_READ | PROT_WRITE | PROT_EXEC,
	CodeFlags = MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT,
	CodeSize = 0x200000,
	
	DataProt = PROT_READ | PROT_WRITE,
	DataFlags = MAP_PRIVATE | MAP_ANONYMOUS,
	DataSize = 0x200000
};


/////// Shuffled TLSF

typedef TLSFLayer<CodeSize, CodeProt, CodeFlags> CodeTLSF;
typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<8, CodeTLSF>, CodeTLSF > > CodeHeapType;


/*
typedef TLSFLayer<DataSize, DataProt, DataFlags> DataTLSF;
typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<8, DataTLSF>, DataTLSF > > DataHeapType;
*/

/////// Shuffled Kingsley
/*
class CodeSource : public OneHeap<BumpAlloc<65536, MmapHeap, 64> > {
public:
	enum { Alignment = 16 };
};
typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<4, SizeHeap<FreelistHeap<CodeSource> > >, SizeHeap<CodeSource> > > CodeHeapType;
*/
/*
class DataSource : public OneHeap<BumpAlloc<65536, MmapHeap, 16> > {
public:
	enum { Alignment = 16 };
};
typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<8, SizeHeap<FreelistHeap<DataSource> > >, SizeHeap<DataSource> > > DataHeapType;
*/

/////// DieHard
enum { Numerator = 10, Denominator = 7 };

/*
class LargeCodeHeap : public OneHeap<LargeHeap<MmapWrapper> > {};
typedef ANSIWrapper<CombineHeap<DieHardHeap<Numerator, Denominator, 65536, true, false>, LargeCodeHeap> > CodeHeapType;
*/


class LargeDataHeap : public OneHeap<LargeHeap<MmapWrapper> > {};
typedef ANSIWrapper<CombineHeap<DieHardHeap<Numerator, Denominator, 65536, true, false>, LargeDataHeap> > DataHeapType;


inline static CodeHeapType* getCodeHeap() {
	static char buf[sizeof(CodeHeapType)];
	static CodeHeapType* _theCodeHeap = new (buf) CodeHeapType;
	return _theCodeHeap;
}

inline static DataHeapType* getDataHeap() {
	static char buf[sizeof(DataHeapType)];
	static DataHeapType* _theDataHeap = new (buf) DataHeapType;
	return _theDataHeap;
}

inline static DataHeapType* getMetadataHeap() {
	static char buf[sizeof(DataHeapType)];
	static DataHeapType* _theMetadataHeap = new (buf) DataHeapType;
	return _theMetadataHeap;
}

void* MD_malloc(size_t sz) {
	return getMetadataHeap()->malloc(sz);
}

void MD_free(void *p) {
	getMetadataHeap()->free(p);
}

void* Code_malloc(size_t sz) {
	DEBUG("Code_malloc");
	return getCodeHeap()->malloc(sz);
}

void Code_free(void *p) {
	DEBUG("Code_free");
	getCodeHeap()->free(p);
}

extern "C" {
	void* DH_malloc(size_t sz) {
		//fprintf(stderr, "Data: malloc(%lu)\n", sz);
		return getDataHeap()->malloc(sz);
	}

	void* DH_calloc(size_t n, size_t sz) {
		//fprintf(stderr, "Data: calloc(%lu, %lu)\n", n, sz);
		return getDataHeap()->calloc(n, sz);
	}

	void* DH_realloc(void *p, size_t sz) {
		//fprintf(stderr, "Data: realloc(%p, %lu)\n", p, sz);
		return getDataHeap()->realloc(p, sz);
	}

	void DH_free(void *p) {
		getDataHeap()->free(p);
	}
}
