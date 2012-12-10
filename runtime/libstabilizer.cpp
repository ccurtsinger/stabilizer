#include <set>
#include <vector>
#include <math.h>

#include "shuffleheap.h"
#include "largeheap.h"
#include "combineheap.h"
#include "diehardheap.h"
#include "heaplayers.h"

#include "TLSFLayer.hpp"

#include "Function.h"

using namespace std;

extern "C" int stabilizer_main(int argc, char **argv);

typedef void(*ctor_t)();

set<Function*> functions;
vector<ctor_t> constructors;

enum {
	DataShuffle = 256,
	DataProt = PROT_READ | PROT_WRITE,
	DataFlags = MAP_PRIVATE | MAP_ANONYMOUS,
	DataSize = 0x200000
};

typedef TLSFLayer<DataSize, DataProt, DataFlags> DataTLSF;
typedef ANSIWrapper<KingsleyHeap<ShuffleHeap<DataShuffle, DataTLSF>, DataTLSF > > DataHeapType;

inline static DataHeapType* getDataHeap() {
	static char buf[sizeof(DataHeapType)];
	static DataHeapType* _theDataHeap = new (buf) DataHeapType;
	return _theDataHeap;
}

extern "C" {
	void stabilizer_register_function(void* base, void* limit, 
		void* relocationTable, size_t tableSize, bool adjacent) {
		
		Function* f = new Function(base, limit, relocationTable, tableSize, adjacent);
		functions.insert(f);
	}
	
	void stabilizer_register_constructor(ctor_t ctor) {
		constructors.push_back(ctor);
	}
	
	uintptr_t stabilizer_stack_padding() {
		return 16 * (rand() % 4096);
	}

	void* stabilizer_malloc(size_t sz) {
		return getDataHeap()->malloc(sz);
	}
	
	void* stabilizer_calloc(size_t n, size_t sz) {
		return getDataHeap()->calloc(n, sz);
	}

	void* stabilizer_realloc(void *p, size_t sz) {
		return getDataHeap()->realloc(p, sz);
	}

	void stabilizer_free(void *p) {
		getDataHeap()->free(p);
	}
	
	void reportDoubleFreeError() {
		abort();
	}
	
	float powif(float b, int e) {
		return powf(b, (float)e);
	}
	
	void stabilizer_ready() {}
}

int main(int argc, char **argv) {
	// Eagerly relocate all functions
	for(set<Function*>::iterator iter = functions.begin(); iter != functions.end(); iter++) {
		Function* f = *iter;
		f->relocate();
	}
	
	// Call a dummy function so I can trap after startup but before execution
	stabilizer_ready();
	
	// Call all constructors
	for(vector<ctor_t>::iterator i = constructors.begin(); i != constructors.end(); i++) {
		(*i)();
	}
	
	// Call the old main function
	int ret = stabilizer_main(argc, argv);
	
	// Free function objects
	for(set<Function*>::iterator i = functions.begin(); i != functions.end(); i++) {
		delete *i;
	}
	
	return ret;
}
