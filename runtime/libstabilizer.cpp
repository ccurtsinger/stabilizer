#include <set>
#include <math.h>

#include "Function.h"

using namespace std;

extern "C" int stabilizer_main(int argc, char **argv);

set<Function*> functions;

extern "C" {
	void stabilizer_register_function(void* base, void* limit, 
		void* relocationTable, size_t tableSize, bool adjacent) {
		
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
	
	void stabilizer_ready() {}
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

