#if !defined(RUNTIME_HEAP_H)
#define RUNTIME_HEAP_H

#include <heaplayers>
#include <shuffleheap.h>

#include "Util.h"

enum {
	DataShuffle = 256,
	DataProt = PROT_READ | PROT_WRITE,
	DataFlags = MAP_PRIVATE | MAP_ANONYMOUS,
	DataSize = 0x2000000,
	
	CodeShuffle = 256,
	CodeProt = PROT_READ | PROT_WRITE | PROT_EXEC,
	CodeFlags = MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT,
	CodeSize = 0x2000000
};

#if defined(USE_TLSF)

#include "TLSFLayer.hpp"

	typedef TLSFLayer<DataSize, DataProt, DataFlags> DataTLSF;
	typedef TLSFLayer<CodeSize, CodeProt, CodeFlags> CodeTLSF;
	
	typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<DataShuffle, DataTLSF>, DataTLSF > > DataHeapType;
	typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<DataShuffle, CodeTLSF>, CodeTLSF > > CodeHeapType;
	
#else
	
#define HL_EXECUTABLE_HEAP 1
	
	class DataSource : public OneHeap<BumpAlloc<DataSize, MmapHeap, 16> > {
	public:
		enum { Alignment = 16 };
	};
	
	class CodeSource : public OneHeap<BumpAlloc<CodeSize, MmapHeap, 64> > {
	public:
		enum { Alignment = 64 };
	};
	
	typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<DataShuffle, SizeHeap<FreelistHeap<DataSource> > >, SizeHeap<DataSource> > > DataHeapType;
	typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<CodeShuffle, SizeHeap<FreelistHeap<CodeSource> > >, SizeHeap<CodeSource> > > CodeHeapType;

#endif
	
inline static DataHeapType* getDataHeap() {
	static char buf[sizeof(DataHeapType)];
	static DataHeapType* _theDataHeap = new (buf) DataHeapType;
	return _theDataHeap;
}

inline static CodeHeapType* getCodeHeap() {
	static char buf[sizeof(CodeHeapType)];
	static CodeHeapType* _theCodeHeap = new (buf) CodeHeapType;
	return _theCodeHeap;
}

#endif
