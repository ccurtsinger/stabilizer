#include <set>
#include <vector>
#include <math.h>
#include <signal.h>
#include <stdlib.h>
#include <execinfo.h>

#include "Function.h"
#include "Debug.h"
#include "Heap.h"
#include "Pile.h"
#include "Context.h"

using namespace std;

extern "C" int stabilizer_main(int argc, char **argv);

int main(int argc, char** argv);

void onTrap(int sig, siginfo_t* info, Context c);
void onTimer(int sig, siginfo_t* info, Context c);
void onFault(int sig, siginfo_t* info, Context c);

void setTimer(int msec);
void setHandler(int sig, void(*fn)(int, siginfo_t*, Context));

typedef void(*ctor_t)();

set<Function*> functions;
set<Function*> live_functions;
set<uint8_t*> stack_tables;
vector<ctor_t> constructors;

bool rerandomizing = false;
size_t interval = 500;
size_t relocationStep = 1;

void** topFrame = NULL;

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
    DEBUG("Initializing Stabilizer");
    
	topFrame = (void**)__builtin_frame_address(0);
    DEBUG("Stack top is at %p", topFrame);
	
	// Register signal handlers
	_AnyX86(setHandler(SIGTRAP, onTrap));
	_PPC(setHandler(SIGILL, onTrap));
	setHandler(SIGALRM, onTimer);
	setHandler(SIGSEGV, onFault);
    DEBUG("Signal handlers installed");
	
	// Lazily relocate functions
	for(set<Function*>::iterator iter = functions.begin(); iter != functions.end(); iter++) {
		Function* f = *iter;
		f->setTrap();
	}
    DEBUG("Trapped all functions");
	
	// Set the re-randomization timer
	setTimer(interval);
    DEBUG("Set re-randomization timer");
	
	// Call all constructors
	for(vector<ctor_t>::iterator i = constructors.begin(); i != constructors.end(); i++) {
		(*i)();
	}
    DEBUG("Finished with program constructors");
	
	// Call the old main function
	int r = stabilizer_main(argc, argv);
    DEBUG("Shutting down");
    
    return r;
}

extern "C" {
	void stabilizer_register_function(void* codeBase, void* codeLimit, void* tableBase, size_t tableSize, bool adjacent, uint8_t* stackTable) {
		Function* f = new Function(codeBase, codeLimit, tableBase, tableSize, adjacent, stackTable);
		functions.insert(f);
	}

	void stabilizer_register_constructor(ctor_t ctor) {
		constructors.push_back(ctor);
	}
	
	void stabilizer_register_stack_table(uint8_t* table) {
		stack_tables.insert(table);
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
        ABORT("Double free error");
	}
}

void onTrap(int sig, siginfo_t* info, Context c) {
	// Back up one byte on x86/x86_64
    _AnyX86(c.ip() = (void*)((uintptr_t)c.ip() - 1));

	// Extract the trapped function (stored next to the trap instruction)
    FunctionHeader* h = (FunctionHeader*)c.ip();
	Function* f = h->obj;
	
	// If the trap was placed to trigger a re-randomization
	if(rerandomizing) {
        DEBUG("Re-randomization started after trap on %p", c.ip());
		live_functions.empty();
		
		// Mark all on-stack function locations as used
        Stack s = c.stack();
        while(s.fp() != topFrame) {
			Pile::mark(s.ret());
            s++;
		}
		
		// Mark the current instruction pointer as used
		Pile::mark((void*)c.ip());
		
		// Mark the top return address on the stack as used
		Pile::mark(*(void**)c.sp());
		
		Pile::sweep();
		
		rerandomizing = false;
		setTimer(interval);
	}

	// Relocate the function
	f->relocate(relocationStep);
	live_functions.insert(f);

    c.ip() = f->getCurrentLocation();
}

void onTimer(int sig, siginfo_t* info, Context c) {
    DEBUG("Re-randomization timer fired at %p", c.ip());
    
	relocationStep++;

	uintptr_t ip = (uintptr_t)c.ip();
	
	if(functions.size() == 0) {
        DEBUG("Re-randomizing stack pad tables");
		for(set<uint8_t*>::iterator iter = stack_tables.begin(); iter != stack_tables.end(); iter++) {
			uint8_t* table = *iter;
			for(size_t i=0; i<256; i++) {
				table[i] = getRandomByte();
			}
		}
		
		setTimer(interval);
		
	} else {
        DEBUG("Placing traps");
		for(set<Function*>::iterator iter = live_functions.begin(); iter != live_functions.end(); iter++) {
			Function* f = *iter;

			if((uintptr_t)f->getCodeBase() > ip || ip - (uintptr_t)f->getCodeBase() > sizeof(Jump)) {
				f->setTrap();
			} else {
                DEBUG("Skipping trap at %p. Overlaps with return from timer handler.", f->getCodeBase());
            }
		}
	}
	
	rerandomizing = true;
}

void onFault(int sig, siginfo_t* info, Context c) {
    ABORT("Fault at %p, accessing address %p", c.ip(), info->si_addr);
}

void setTimer(int msec) {
	struct itimerval timer;

	timer.it_value.tv_sec = (msec - msec % 1000) / 1000;
	timer.it_value.tv_usec = 1000 * (msec % 1000);
	timer.it_interval.tv_sec = 0;
	timer.it_interval.tv_usec = 0;

	setitimer(ITIMER_REAL, &timer, 0);
}

void setHandler(int sig, void(*fn)(int, siginfo_t*, Context)) {
	struct sigaction sa;
	sa.sa_sigaction = (void(*)(int, siginfo_t*, void*))fn;
	sa.sa_flags = SA_SIGINFO;
	sigaction(sig, &sa, NULL);
}
