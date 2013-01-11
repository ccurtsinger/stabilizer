#include <set>
#include <vector>
#include <math.h>
#include <signal.h>
#include <stdlib.h>
#include <execinfo.h>

#include "mwc64.h"

#include "Function.h"
#include "Heap.h"
#include "Pile.h"

using namespace std;

extern "C" int stabilizer_main(int argc, char **argv);

int main(int argc, char** argv);
extern "C" void stabilizer_ready();

void onTrap(int sig, siginfo_t* info, void* c);
void onTimer(int sig, siginfo_t* info, void* c);
void onFault(int sig, siginfo_t* info, void* c);

void setTimer(int msec);
void setHandler(int sig, void(*fn)(int, siginfo_t*, void*));

typedef void(*ctor_t)();

set<Function*> functions;
set<Function*> live_functions;
vector<ctor_t> constructors;

bool rerandomizing = false;
size_t interval = 500;
size_t relocationStep = 1;

void** topFrame = NULL;

enum {
	StackAlignment = 16,
	RandIntChunks = 4
};

/**
 * Entry point for a program run with Stabilizer.  The program's existing
 * main function has been renamed 'stabilizer_main' by the compiler pass.
 * 
 * 1. Save the current top of the stack
 * 2. Set signal handlers for debug traps, timers, and segfaults for error handling
 * 3. Place a trap instruction at the start of each randomizable function to trigger relocation on-demand
 * 4. Set the re-randomization timer
 * 5. Call module constructors
 * 6. Invoke stabilizer_main
 */
int main(int argc, char **argv) {
	topFrame = (void**)__builtin_frame_address(0);
	
	// Register signal handlers
	setHandler(SIGTRAP, onTrap);
	setHandler(SIGALRM, onTimer);
	setHandler(SIGSEGV, onFault);
	setHandler(SIGBUS, onFault);
	setHandler(SIGABRT, onFault);
	setHandler(SIGILL, onFault);
	
	// Lazily relocate functions
	for(set<Function*>::iterator iter = functions.begin(); iter != functions.end(); iter++) {
		Function* f = *iter;
		f->setTrap();
	}
	
	// Set the re-randomization timer
	setTimer(interval);
	
	// Call a dummy function so I can trap after startup but before execution of any randomized code
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
		static MWC64 _rng;
		static size_t count = 0;
		uint8_t rands[RandIntChunks * 8];
		
		if(count == 0) {
			for(;count < RandIntChunks; count += 8) {
				*(uint64_t*)&rands[count] = _rng.next();
			}
		}
		
		count--;
		return StackAlignment * rands[count];
		
		//return StackAlignment * modulo<PAGESIZE/StackAlignment>(_rng.next());
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
		if(getDataHeap()->getSize(p) == 0) {
			free(p);
		} else {
			getDataHeap()->free(p);
		}
	}

	void reportDoubleFreeError() {
		abort();
	}
	
	float powif(float b, int e) {
		return powf(b, (float)e);
	}
	
	void stabilizer_ready() {}
}

void panic(void* ip, void** fp, bool quit) {
	void* real_buffer[100];
	void* debug_buffer[100];
	bool current[100];
	
	real_buffer[0] = ip;
	
	size_t num = 1;
	while(fp != topFrame) {
		real_buffer[num] = fp[1];
		fp = (void**)fp[0];
		num++;
	}
	
	// Find any relocated functions in the backtrace and rewrite them to
	// the original code location.
	for(size_t i=0; i<num; i++) {
		void* p = real_buffer[i];
		debug_buffer[i] = p;
		current[i] = true;
		
		for(set<Function*>::iterator iter = functions.begin(); iter != functions.end(); iter++) {
			Function* f = *iter;
			f->selfCheck();
			if(f->getCurrentLocation() != NULL) {
				uintptr_t offset = (uintptr_t)p - (uintptr_t)f->getCurrentLocation();
				if(offset < f->getCodeSize()) {
					debug_buffer[i] = (void*)((uintptr_t)f->getCodeBase() + offset);
				} else {
					/*offset = (uintptr_t)p - (uintptr_t)f->getOldLocation();
					if(offset < f->getCodeSize()) {
						debug_buffer[i] = (void*)((uintptr_t)f->getCodeBase() + offset);
						current[i] = false;
					}*/
					// TODO: Scan the GC pile for matching functions and rewrite those addresses
				}
			}
		}
	}
	
	char** strings = backtrace_symbols(debug_buffer, num);

    if (strings == NULL) {
        perror("backtrace_symbols");
		abort();
    }
	
	for(size_t i=0; i<num; i++) {
		printf("%s [at %p%s]\n", strings[i], real_buffer[i], current[i] ? "" : " OLD!");
	}
	
	free(strings);
	if(quit) {
		abort();
	}
}

void onTrap(int sig, siginfo_t* info, void* c) {
	// Back up one instruction
	SET_CONTEXT_IP(c, (intptr_t)GET_CONTEXT_IP(c)-1);
	
	// Extract the trapped function (stored next to the trap instruction)
	void** p = (void**)GET_CONTEXT_IP(c);
	Function* f = (Function*)p[1];
	
	// If the trap was placed to trigger a re-randomization
	if(rerandomizing) {
		/*for(set<Function*>::iterator iter = live_functions.begin(); iter != live_functions.end(); iter++) {
			(*iter)->setTrap();
		}*/
		live_functions.empty();
		
		// Mark all on-stack function locations as used
		void** fp = (void**)GET_CONTEXT_FP(c);
		while(fp != topFrame) {
			Pile::mark(fp[1]);
			fp = (void**)fp[0];
		}
		
		// Mark the current instruction pointer as used
		Pile::mark((void*)GET_CONTEXT_IP(c));
		
		// Mark the top return address on the stack as used
		Pile::mark(*(void**)GET_CONTEXT_SP(c));

		/*void* buffer[512];
		size_t depth = backtrace(buffer, 512);
		for(size_t i=0; i<depth; i++) {
			printf("  %p\n", buffer[i]);
			Pile::mark(buffer[i]);
		}*/
		
		Pile::sweep();
		
		rerandomizing = false;
		setTimer(interval);
	}

	// Relocate the function
	f->relocate(relocationStep);
	live_functions.insert(f);

	SET_CONTEXT_IP(c, (uintptr_t)f->getCurrentLocation());
}

void onTimer(int sig, siginfo_t* info, void* c) {
	relocationStep++;

	uintptr_t ip = (uintptr_t)GET_CONTEXT_IP(c);
	
	for(set<Function*>::iterator iter = live_functions.begin(); iter != live_functions.end(); iter++) {
		Function* f = *iter;
		
		if((uintptr_t)f->getCodeBase() > ip || ip - (uintptr_t)f->getCodeBase() > sizeof(Jump)) {
			f->setTrap();
		}
	}
	
	rerandomizing = true;
}

void onFault(int sig, siginfo_t* info, void* c) {
	printf("Fault at %p, accessing %p\n", (void*)GET_CONTEXT_IP(c), info->si_addr);
	
	if(sig == SIGSEGV) {
		printf("SIGSEGV\n");
	} else if(sig == SIGABRT) {
		printf("SIGABRT\n");
	} else if(sig == SIGILL) {
		printf("SIGILL\n");
		printf("  %p\n", *(void**)GET_CONTEXT_IP(c));
	}

	panic((void*)GET_CONTEXT_IP(c), (void**)GET_CONTEXT_FP(c), true);
}

void setTimer(int msec) {
	struct itimerval timer;

	timer.it_value.tv_sec = (msec - msec % 1000) / 1000;
	timer.it_value.tv_usec = 1000 * (msec % 1000);
	timer.it_interval.tv_sec = 0;
	timer.it_interval.tv_usec = 0;

	setitimer(ITIMER_REAL, &timer, 0);
}

void setHandler(int sig, void(*fn)(int, siginfo_t*, void*)) {
	struct sigaction sa;
	sa.sa_sigaction = fn;
	sa.sa_flags = SA_SIGINFO;
	sigaction(sig, &sa, NULL);
}
