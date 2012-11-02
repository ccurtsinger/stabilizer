#include "Global.h"
#include "Function.h"
#include "FunctionLocation.h"
#include "Jump.h"
#include "Util.h"
#include "Metadata.h"
#include "Heaps.h"

#include "list.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include <sys/time.h>

#if !defined(_XOPEN_SOURCE)
// Digging inside of ucontext_t is deprecated unless this macros is defined
#define _XOPEN_SOURCE
#endif

#include <ucontext.h>

extern "C" int stabilizer_main(int argc, char **argv);



using namespace std;
using namespace stabilizer;

#ifndef __POWERPC__
#define LAZY_RELOCATION
#define RERANDOMIZATION
#endif

// If a function location is not recoverable after this many relocations, just abandon it.
enum { WriteoffThreshold = 10 };

// If a function has been trapped and relocated this many times, relocated eagerly
enum { EagerThreshold = 0 };

// Increase the rerandomization interval by (TargetRerand+1)/TargetRerand
// After a warmup period, no single period of rerandomization will make up
// more than 1/TargetRerand of total time
enum { TargetRerand = 15 };
enum { StartingInterval = 250 };

namespace stabilizer {

	size_t rerand_interval = StartingInterval;

	typedef struct frame_entry {
		void *frame;
		void *old_frame;
	} frame_entry_t;

	typedef struct global_entry {
		void *original;
		void *relocated;
		size_t size;
	} global_entry_t;
	
	list<Function*> functions;
	list<Function*> live_functions;
	list<FunctionLocation*> defunct_locations;
	
	list<frame_entry_t*> live_frames;

	/*extern "C" void stabilizer_register_global(void *p, size_t sz) {
		DEBUG("Registering global %p\n", p);
		Global *g = new Global(p, sz);

		globals[p] = g;
	}*/
    
#ifdef LAZY_RELOCATION
    void trap(int sig, siginfo_t *info, void *c) {
        SET_CONTEXT_IP(c, (intptr_t)GET_CONTEXT_IP(c)-1);
        struct fn_header *h = (struct fn_header*)GET_CONTEXT_IP(c);

        Function *f = h->obj;
        live_functions.add(f);
        
        f->restoreHeader();
        f->relocate();
    }
    
    extern "C" void doRelocation(fn_header* p) {
    	Function* f = p->obj;
    	live_functions.add(f);
    	f->restoreHeader();
    	f->relocate();
    }
#endif
    
    void stabilizer_set_trap_handler() {
#ifdef LAZY_RELOCATION
        static bool initialized = false;
        if(!initialized) {
            struct sigaction sa;
            sa.sa_sigaction = &trap;
            sa.sa_flags = SA_SIGINFO;

            sigaction(SIGTRAP, &sa, NULL);
            
            initialized = true;
        }
#endif
    }

	extern "C" void stabilizer_register_function(struct fn_info *info) {
		DEBUG("Registering function %s", info->name);
		Function *f = new Function(info);

#ifdef LAZY_RELOCATION
		f->placeBreakpoint();
#else
		f->relocate();
#endif
		functions.add(f);
	}
	
	extern "C" void* stabilizer_relocate_frame(frame_entry_t *entry, size_t sz) {
		if(entry->old_frame != NULL) {
			DH_free(entry->old_frame);
			entry->old_frame = NULL;
		}

		entry->frame = DH_malloc(sz);

		live_frames.add(entry);

		return entry->frame;
	}

	void set_timer(int msec, void (*handler)(int, siginfo_t*, void*)) {
		struct sigaction sa;
		sa.sa_sigaction = handler;
		sa.sa_flags = SA_SIGINFO;

		sigaction(SIGALRM, &sa, NULL);
	
		struct itimerval timer;

		timer.it_value.tv_sec = (msec - msec % 1000) / 1000;
		timer.it_value.tv_usec = 1000 * (msec % 1000);
		timer.it_interval.tv_sec = 0;
		timer.it_interval.tv_usec = 0;

		setitimer(ITIMER_REAL, &timer, 0);
	}

	void segv(int sig, siginfo_t *info, void *c) {
		fprintf(stderr, "SIGSEGV at %p accessing memory at %p\n", (void*)GET_CONTEXT_IP(c), info->si_addr);
		abort();
	}

	void rerandomize(int sig, siginfo_t *info, void *ctx) {
		
		// Loop over all defunct function locations
		for(auto iter = defunct_locations.begin(); iter != defunct_locations.end(); iter.next()) {
			FunctionLocation* l = *iter;
			
			if(l->getUsers() == 0) {
				// If all references have disappeared, free it
				delete l;
				iter.remove();
			} else {
				// Otherwise, keep track of how long it has been defunct but non-freeable
				l->defunctCount++;
				if(WriteoffThreshold != 0 && l->defunctCount >= WriteoffThreshold) {
					// Give up on freeing this location
					iter.remove();
					DEBUG("Writing off FunctionLocation at %p as unrecoverable memory", l->getBase());
				}
			}
		}

		// Loop over all live stack frames
		for(auto iter = live_frames.begin(); iter != live_frames.end(); iter.next()) {
			frame_entry_t* entry = *iter;
			// Move the current frame to the old frame
			entry->old_frame = entry->frame;
			// Clear the current frame to trigger an allocation on the next call
			entry->frame = NULL;
			iter.remove();
		}

		// Loop over all live functions
		for(auto iter = live_functions.begin(); iter != live_functions.end(); iter.next()) {
			Function* f = *iter;
			FunctionLocation* l = f->getCurrentLocation();
			defunct_locations.add(l);
			
#if defined(LAZY_RELOCATION)
			if(EagerThreshold != 0 && f->relocatedCount() >= EagerThreshold) {
				// This function is frequently used, so relocate it eagerly
				f->relocate();
			} else {
				// Set the trap so we can relocate the function next time it's called
				f->placeBreakpoint();
				
				// The function is no longer live, so remove it from the list
				iter.remove();
			}
#else
			f->relocate();
#endif
		}

		rerand_interval = (rerand_interval * (TargetRerand+1)) / TargetRerand;	
		set_timer(rerand_interval, rerandomize);
	}
}

int main(int argc, char **argv) {
#ifdef RERANDOMIZATION
	set_timer(rerand_interval, rerandomize);
#endif

    stabilizer_set_trap_handler();

	struct sigaction sa2;
	sa2.sa_sigaction = &segv;
	sa2.sa_flags = SA_SIGINFO;
	sigaction(SIGSEGV, &sa2, NULL);

	DEBUG("Stabilizer initialized");

	int result = stabilizer_main(argc, argv);

	return result;
}

extern "C" void reportDoubleFreeError() {
	abort();
}

extern "C" float powif(float b, int e) {
	return powf(b, (float)e);
}

