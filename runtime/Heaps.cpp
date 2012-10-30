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
	CodeShuffle = 256,
	CodeProt = PROT_READ | PROT_WRITE | PROT_EXEC,
	CodeFlags = MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT,
	CodeSize = 0x200000,
	
	DataShuffle = 256,
	DataProt = PROT_READ | PROT_WRITE,
	DataFlags = MAP_PRIVATE | MAP_ANONYMOUS,
	DataSize = 0x200000,
	
	MetadataShuffle = 1,
	MetadataProt = PROT_READ | PROT_WRITE,
	MetadataFlags = MAP_PRIVATE | MAP_ANONYMOUS,
	MetadataSize = 0x200000
};

#define DIEHARD 1
#define TLSF 2
#define DLMALLOC 3
#define KINGSLEY 4

#define CODEHEAP TLSF
#define DATAHEAP TLSF
#define MDHEAP 	 TLSF

enum { Numerator = 10, Denominator = 7 };

#if CODEHEAP == DIEHARD
	class LargeCodeHeap : public OneHeap<LargeHeap<MmapWrapper> > {};
	typedef ANSIWrapper<CombineHeap<DieHardHeap<Numerator, Denominator, 65536, true, false>, LargeCodeHeap> > CodeHeapType;
#elif CODEHEAP == TLSF
	typedef TLSFLayer<CodeSize, CodeProt, CodeFlags> CodeTLSF;
	typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<CodeShuffle, CodeTLSF>, CodeTLSF > > CodeHeapType;
#elif CODEHEAP == DLMALLOC
	typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<CodeShuffle, LeaMallocHeap>, LeaMallocHeap> > CodeHeapType;
#else
	// The alignment MUST be different from the Data and Metadata heaps or they'll share a source
	class CodeSource : public OneHeap<BumpAlloc<65536, MmapHeap, 64> > {
	public:
		enum { Alignment = 16 };
	};
	typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<CodeShuffle, SizeHeap<FreelistHeap<CodeSource> > >, SizeHeap<CodeSource> > > CodeHeapType;
#endif


#if DATAHEAP == DIEHARD
	class LargeDataHeap : public OneHeap<LargeHeap<MmapWrapper> > {};
	typedef ANSIWrapper<CombineHeap<DieHardHeap<Numerator, Denominator, 65536, true, false>, LargeDataHeap> > DataHeapType;
#elif DATAHEAP == TLSF
	typedef TLSFLayer<DataSize, DataProt, DataFlags> DataTLSF;
	typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<DataShuffle, DataTLSF>, DataTLSF > > DataHeapType;
#elif DATAHEAP == DLMALLOC
	//typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<DataShuffle, LeaMallocHeap>, LeaMallocHeap> > DataHeapType;
	typedef ANSIWrapper<LeaMallocHeap> DataHeapType;
#else
	// The alignment MUST be different from the Code and Metadata heaps or they'll share a source
	class DataSource : public OneHeap<BumpAlloc<65536, MmapHeap, 16> > {
	public:
		enum { Alignment = 16 };
	};
	typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<DataShuffle, SizeHeap<FreelistHeap<DataSource> > >, SizeHeap<DataSource> > > DataHeapType;
#endif

#if MDHEAP == DIEHARD
	class LargeMetadataHeap : public OneHeap<LargeHeap<MmapWrapper> > {};
	typedef ANSIWrapper<CombineHeap<DieHardHeap<Numerator, Denominator, 65536, true, false>, LargeMetadataHeap> > MetadataHeapType;
#elif MDHEAP == TLSF
	typedef TLSFLayer<MetadataSize, MetadataProt, MetadataFlags> MetadataTLSF;
	typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<MetadataShuffle, MetadataTLSF>, MetadataTLSF > > MetadataHeapType;
#elif MDHEAP == DLMALLOC
	//typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<MetadataShuffle, LeaMallocHeap>, LeaMallocHeap> > MetadataHeapType;
	typedef ANSIWrapper<LeaMallocHeap> MetadataHeapType;
#else
	// The alignment MUST be different from the Code and Data heaps or they'll share a source
	class MetadataSource : public OneHeap<BumpAlloc<65536, MmapHeap, 32> > {
	public:
		enum { Alignment = 16 };
	};
	typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<MetadataShuffle, SizeHeap<FreelistHeap<MetadataSource> > >, SizeHeap<MetadataSource> > > MetadataHeapType;
#endif

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

inline static MetadataHeapType* getMetadataHeap() {
	static char buf[sizeof(MetadataHeapType)];
	static MetadataHeapType* _theMetadataHeap = new (buf) MetadataHeapType;
	return _theMetadataHeap;
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

extern "C" {
	void* DH_malloc(size_t sz) {
		fprintf(stderr,"malloc: %lu\n", sz);
		return getDataHeap()->malloc(sz);
	}

	void* DH_calloc(size_t n, size_t sz) {
		return getDataHeap()->calloc(n, sz);
	}

	void* DH_realloc(void *p, size_t sz) {
		return getDataHeap()->realloc(p, sz);
	}

	void DH_free(void *p) {
		getDataHeap()->free(p);
	}
}
