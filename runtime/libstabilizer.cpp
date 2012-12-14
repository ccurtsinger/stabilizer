#include <set>
#include <vector>
#include <math.h>
#include <signal.h>
#include <stdlib.h>

#include "Function.h"
#include "Heap.h"

using namespace std;

extern "C" int stabilizer_main(int argc, char **argv);

void trap(int sig, siginfo_t* info, void* c);
void timer(int sig, siginfo_t* info, void* c);
void set_timer(int msec);

typedef void(*ctor_t)();

set<Function*> functions;
vector<ctor_t> constructors;

bool rerandomizing = false;
size_t interval = 500;
size_t relocationStep = 0;

void** topFrame = NULL;

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

void walk_stack(void** fp) {
	while(fp != topFrame) {
		bool relocated = false;
		for(set<Function*>::iterator iter = functions.begin(); iter != functions.end() && !relocated; iter++) {
			Function* f = *iter;
			relocated |= f->update(relocationStep, &fp[1]);
		}
		
		fp = (void**)fp[0];
	}
}

void trap(int sig, siginfo_t* info, void* c) {
	// Back up one instruction
	SET_CONTEXT_IP(c, (intptr_t)GET_CONTEXT_IP(c)-1);
	
	// If the trap was placed to trigger a re-randomization
	if(rerandomizing) {
		// Update code pointers on the stack
		walk_stack((void**)GET_CONTEXT_FP(c));
		
		// TODO: Update the link register on PowerPC
		
		// Clean up all old code locations
		for(set<Function*>::iterator iter = functions.begin(); iter != functions.end(); iter++) {
			Function* f = *iter;
			f->cleanup();
		}
		
		rerandomizing = false;
		set_timer(interval);
	}
	
	// Extract the trapped function (stored next to the trap instruction
	void** p = (void**)GET_CONTEXT_IP(c);
	Function* f = (Function*)p[1];
	
	// Relocate the function
	f->relocate(relocationStep);
}

void timer(int sig, siginfo_t* info, void* c) {
	relocationStep++;
	
	for(set<Function*>::iterator iter = functions.begin(); iter != functions.end(); iter++) {
		Function* f = *iter;
		f->setTrap();
	}
	
	rerandomizing = true;
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
