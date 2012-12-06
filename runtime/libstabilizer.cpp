#include <math.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/time.h>

#include <set>

#include "Util.h"
#include "Jump.h"

using namespace std;

extern "C" int stabilizer_main(int argc, char **argv);

struct Function {
private:
	void* _base;
	void* _limit;
	void* _relocationTable;
	size_t _tableSize;
	bool _adjacent;
	
	void* _currentBase;
	
public:
	Function(void* base, void* limit, void* relocationTable, size_t tableSize, bool adjacent) :
		_base(base), _limit(limit), _currentBase(base), _relocationTable(relocationTable),
		_tableSize(tableSize), _adjacent(adjacent) {}
	
	void relocate() {
		size_t codeSize = (uintptr_t)_limit - (uintptr_t)_base;
		size_t sz = codeSize;
		
		if(_adjacent) {
			sz += _tableSize;
		}
		
		void* p = mmap(NULL, sz, PROT_READ | PROT_WRITE | PROT_EXEC,
			MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT, -1, 0);
		
		memcpy(p, _base, codeSize);
		
		if(_adjacent) {
			void* tableBase = (uint8_t*)p + codeSize;
			memcpy(tableBase, _relocationTable, _tableSize);
		}
		
		void* jumpBase = (void*)ALIGN_DOWN(_base, PAGESIZE);
		void* jumpLimit = (void*)ALIGN_UP((uintptr_t)_base + sizeof(Jump), PAGESIZE);
		size_t jumpSize = (uintptr_t)jumpLimit - (uintptr_t)jumpBase;
		
		mprotect(jumpBase, jumpSize, PROT_READ | PROT_WRITE | PROT_EXEC);
		
		new(_base) Jump(p);
	}
};

set<Function*> functions;

extern "C" {
	void stabilizer_register_function(void* base, void* limit, 
		void* relocationTable, size_t tableSize, bool adjacent) {
		
		printf("Registered function %p to %p\n", base, limit);
		printf("  Relocation table: %p\n", relocationTable);
		printf("  size: %lu, adjacent? %s\n", tableSize, adjacent ? "yes" : "no");
		
		Function* f = new Function(base, limit, relocationTable, tableSize, adjacent);
		functions.insert(f);
	}

	void* stabilizer_malloc(size_t sz) {
		return malloc(sz);
	}
	
	void* stabilizer_calloc(size_t n, size_t sz) {
		return calloc(n, sz);
	}

	void* stabilizer_realloc(void *p, size_t sz) {
		return realloc(p, sz);
	}

	void stabilizer_free(void *p) {
		free(p);
	}
	
	void stabilizer_ready() {
		printf("Ready!\n");
	}
}

int main(int argc, char **argv) {
	for(set<Function*>::iterator iter = functions.begin(); iter != functions.end(); iter++) {
		Function* f = *iter;
		f->relocate();
	}
	
	stabilizer_ready();
	
	return stabilizer_main(argc, argv);
}

extern "C" void reportDoubleFreeError() {
	abort();
}

extern "C" float powif(float b, int e) {
	return powf(b, (float)e);
}

