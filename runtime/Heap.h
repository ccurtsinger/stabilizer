#if !defined(RUNTIME_HEAP_H)
#define RUNTIME_HEAP_H

#include <heaplayers>
#include <shuffleheap.h>

#include "Util.h"
#include "MMapSource.h"

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

class DataSource : public SizeHeap<FreelistHeap<BumpAlloc<DataSize, MMapSource<DataProt, DataFlags>, 16> > > {};
class CodeSource : public SizeHeap<FreelistHeap<BumpAlloc<CodeSize, MMapSource<CodeProt, CodeFlags>, CODE_ALIGN> > > {};
	
typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<DataShuffle, DataSource>, DataSource> > DataHeapType;
typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<CodeShuffle, CodeSource>, CodeSource> > CodeHeapType;
	
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
