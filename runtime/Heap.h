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
	
DataHeapType* getDataHeap();
CodeHeapType* getCodeHeap();

#endif
