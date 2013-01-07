#include <set>
#include <vector>
#include <math.h>
#include <signal.h>
#include <stdlib.h>
#include <execinfo.h>

#include "Function.h"
#include "Heap.h"

using namespace std;

extern "C" int stabilizer_main(int argc, char **argv);

void trap(int sig, siginfo_t* info, void* c);
void timer(int sig, siginfo_t* info, void* c);
void set_timer(int msec);

typedef void(*ctor_t)();

set<Function*> functions;
set<Function*> live_functions;

vector<ctor_t> constructors;

bool rerandomizing = false;
size_t interval = 500;
size_t relocationStep = 1;

void** topFrame = NULL;

enum {
	StackAlignment = 16
};

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
		return StackAlignment * (rand() % (PAGESIZE/StackAlignment));
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
	
	//size_t num = backtrace(real_buffer, 100);
	
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
					offset = (uintptr_t)p - (uintptr_t)f->getOldLocation();
					if(offset < f->getCodeSize()) {
						debug_buffer[i] = (void*)((uintptr_t)f->getCodeBase() + offset);
						current[i] = false;
					}
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

inline set<Function*> walk_stack(void** fp) {
	set<Function*> new_live_functions;
	
	while(fp != topFrame) {
		bool relocated = false;
		
		for(set<Function*>::iterator iter = functions.begin(); iter != functions.end() && !relocated; iter++) {
			Function* f = *iter;
			if(f->update(relocationStep, &fp[1])) {
				new_live_functions.insert(f);
				relocated = true;
			}
		}
		
		fp = (void**)fp[0];
	}
	
	return new_live_functions;
}

void* fixPointer(void* p) {
	for(set<Function*>::iterator iter = functions.begin(); iter != functions.end(); iter++) {
		Function* f = *iter;
		
		uintptr_t offset;
		
		offset = (uintptr_t)p - (uintptr_t)f->getCodeBase();
		if(offset < f->getCodeSize()) {
			return p;
		}
		
		if(f->getCurrentLocation() != NULL) {
			offset = (uintptr_t)p - (uintptr_t)f->getCurrentLocation();
			if(offset < f->getCodeSize()) {
				return (void*)((uintptr_t)f->getCodeBase() + offset);
			}
		}
		
		if(f->getOldLocation() != NULL) {
			offset = (uintptr_t)p - (uintptr_t)f->getOldLocation();
			if(offset < f->getCodeSize()) {
				return (void*)((uintptr_t)f->getCodeBase() + offset);
			}
		}
	}
	
	return p;
}

void showPointer(void* p) {
	void* ptr[1];
	ptr[0] = fixPointer(p);
	char** strings = backtrace_symbols(ptr, 1);
	printf("%p:    %s\n", p, strings[0]);
	free(strings);
}

void trap(int sig, siginfo_t* info, void* c) {
	// Back up one instruction
	SET_CONTEXT_IP(c, (intptr_t)GET_CONTEXT_IP(c)-1);
	
	// If the trap was placed to trigger a re-randomization
	if(rerandomizing) {
		for(set<Function*>::iterator iter = functions.begin(); iter != functions.end(); iter++) {
			(*iter)->relocate(relocationStep);
			//(*iter)->setTrap();
		}
		
		printf("BEFORE:\n");
		panic((void*)GET_CONTEXT_IP(c), (void**)GET_CONTEXT_FP(c), false);
		
		// Update code pointers on the stack
		set<Function*> new_live_functions = walk_stack((void**)GET_CONTEXT_FP(c));
		
		// Fix the return address at the top of the stack (with no frame saved)
		void** sp = (void**)GET_CONTEXT_SP(c);
		bool relocated = false;
		for(set<Function*>::iterator iter = functions.begin(); iter != functions.end() && !relocated; iter++) {
			Function* f = *iter;
			if(f->update(relocationStep, sp)) {
				new_live_functions.insert(f);
				relocated = true;
			}
		}
		if(!relocated) {
			printf("CRAP: %p\n", *sp);
		}
		
		printf("on-stack return address: %p\n", *sp);
		showPointer(*sp);
		
		printf("\n\nAFTER:\n");
		panic((void*)GET_CONTEXT_IP(c), (void**)GET_CONTEXT_FP(c), false);
		
		// TODO: Update the link register on PowerPC
		
		// Clean up all old code locations
		for(set<Function*>::iterator iter = functions.begin(); iter != functions.end(); iter++) {
			Function* f = *iter;
			f->cleanup();
		}
		
		live_functions = new_live_functions;
		
		rerandomizing = false;
		set_timer(interval);
	}
	
	// Extract the trapped function (stored next to the trap instruction
	void** p = (void**)GET_CONTEXT_IP(c);
	Function* f = (Function*)p[1];

	// Relocate the function
	f->relocate(relocationStep);
	//f->setTrap();
	
	live_functions.insert(f);
	
	printf("Calling %p\n", f->getCurrentLocation());
	showPointer(f->getCodeBase());
	printf(" Returns to %p\n", *(void**)GET_CONTEXT_SP(c));
	showPointer(*(void**)GET_CONTEXT_SP(c));
	
	SET_CONTEXT_IP(c, (uintptr_t)f->getCurrentLocation());
}

void timer(int sig, siginfo_t* info, void* c) {
	relocationStep++;
	
	for(set<Function*>::iterator iter = functions.begin(); iter != functions.end(); iter++) {
		Function* f = *iter;
		f->setTrap();
	}
	
	rerandomizing = true;
}

void segv(int sig, siginfo_t* info, void* c) {
	printf("Segfault at %p, accessing %p\n", (void*)GET_CONTEXT_IP(c), info->si_addr);
	panic((void*)GET_CONTEXT_IP(c), (void**)GET_CONTEXT_FP(c), true);
}

void set_timer(int msec) {
	struct itimerval timer;

	timer.it_value.tv_sec = (msec - msec % 1000) / 1000;
	timer.it_value.tv_usec = 1000 * (msec % 1000);
	timer.it_interval.tv_sec = 0;
	timer.it_interval.tv_usec = 0;

	setitimer(ITIMER_REAL, &timer, 0);
}

void set_signal_handler(int sig, void(*fn)(int, siginfo_t*, void*)) {
	struct sigaction sa;
	sa.sa_sigaction = fn;
	sa.sa_flags = SA_SIGINFO;
	sigaction(sig, &sa, NULL);
}

int main(int argc, char **argv) {
	topFrame = (void**)__builtin_frame_address(0);
	
	// Register signal handlers
	set_signal_handler(SIGTRAP, trap);
	set_signal_handler(SIGALRM, timer);
	set_signal_handler(SIGSEGV, segv);
	set_signal_handler(SIGBUS, segv);
	
	// Lazily relocate functions
	for(set<Function*>::iterator iter = functions.begin(); iter != functions.end(); iter++) {
		Function* f = *iter;
		f->setTrap();
	}
	
	// Set the re-randomization timer
	set_timer(interval);
	
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
