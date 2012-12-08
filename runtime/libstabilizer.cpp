#include <set>
#include <vector>
#include <math.h>
#include <stdlib.h>

#include "Function.h"

using namespace std;

extern "C" int stabilizer_main(int argc, char **argv);

typedef void(*ctor_t)();

set<Function*> functions;
vector<ctor_t> constructors;

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
