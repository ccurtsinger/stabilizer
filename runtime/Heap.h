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

template<int Prot, int Flags> class MMapSource {
private:
	bool _exhausted32;
	
public:
	enum { Alignment = PAGESIZE };

	MMapSource() {
		_exhausted32 = false;
	}
	
	inline void* malloc(size_t sz) {
		void* ptr;
		
		if(Flags & MAP_32BIT) {
			// If we haven't exhausted the 32 bit pages
			if(!_exhausted32) {
				ptr = mmap(NULL, sz, Prot, Flags, -1, 0);
				
				if(ptr != MAP_FAILED) {
					return ptr;
				} else {
					_exhausted32 = true;
				}
			}
		}
		
		// Try the map without the MAP_32BIT flag set
		ptr = mmap(NULL, sz, Prot, Flags & ~MAP_32BIT, -1, 0);
		
		if(ptr == MAP_FAILED) {
			ptr = NULL;
		}
		
		return ptr;
	}
};

#if defined(USE_TLSF)

#include "TLSFLayer.hpp"

	typedef TLSFLayer<DataSize, DataProt, DataFlags> DataSource;
	typedef TLSFLayer<CodeSize, CodeProt, CodeFlags> CodeSource;

#else
	
#define HL_EXECUTABLE_HEAP 1
	
	class DataSource : public SizeHeap<FreelistHeap<BumpAlloc<DataSize, MMapSource<DataProt, DataFlags>, 16> > > {};
	class CodeSource : public SizeHeap<FreelistHeap<BumpAlloc<CodeSize, MMapSource<CodeProt, CodeFlags>, CODE_ALIGN> > > {};
	
#endif
	
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
