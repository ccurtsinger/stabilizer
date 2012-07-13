#include "Global.h"
#include "Function.h"
#include "FunctionLocation.h"
#include "Jump.h"
#include "Util.h"
#include "Metadata.h"
#include "Heaps.h"

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include <sys/time.h>
#include <ucontext.h>

extern "C" int stabilizer_main(int argc, char **argv);

using namespace std;
using namespace stabilizer;

#ifndef __POWERPC__
#define LAZY_RELOCATION
#define RERANDOMIZATION
#endif

namespace stabilizer {

	size_t rerand_interval = 200;

	typedef struct frame_entry {
		void *frame;
		void *old_frame;
	} frame_entry_t;

	typedef struct global_entry {
		void *original;
		void *relocated;
		size_t size;
	} global_entry_t;

	GlobalMapType globals;
	FunctionListType functions;
	FunctionListType live_functions;

	FunctionLocationListType defunct_locations;
	
	//typedef list<frame_entry_t*, DH_malloc, DH_free> FrameEntryListType;
	typedef vector<frame_entry_t*, MDAllocator<frame_entry_t*> > FrameEntryListType;

	FrameEntryListType live_frames;

	extern "C" void stabilizer_register_global(void *p, size_t sz) {
		DEBUG("Registering global %p\n", p);
		Global *g = new Global(p, sz);

		globals[p] = g;
	}

	extern "C" void stabilizer_register_function(struct fn_info *info) {
		DEBUG("Registering function %s", info->name);
		Function *f = new Function(info, &globals);

#ifdef LAZY_RELOCATION
		f->placeBreakpoint();
#else
		f->relocate();
#endif
		functions.push_back(f);
	}
	
	extern "C" void* stabilizer_relocate_frame(frame_entry_t *entry, size_t sz) {
		if(entry->old_frame != NULL) {
			DH_free(entry->old_frame);
			entry->old_frame = NULL;
		}

		entry->frame = DH_malloc(sz);

		live_frames.push_back(entry);

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
	
#ifdef LAZY_RELOCATION
	void trap(int sig, siginfo_t *info, void *c) {
		SET_CONTEXT_IP(c, (intptr_t)GET_CONTEXT_IP(c)-1);
		struct fn_header *h = (struct fn_header*)GET_CONTEXT_IP(c);

		Function *f = h->obj;

		live_functions.push_back(f);
		f->restoreHeader();
		f->relocate();
	}
#endif

	void segv(int sig, siginfo_t *info, void *c) {
		fprintf(stderr, "SIGSEGV at %p\n", info->si_addr);
		abort();
	}

	void rerandomize(int sig, siginfo_t *info, void *c) {
		FunctionLocationListType new_defunct;

		for(FunctionLocationListType::iterator defunct_i = defunct_locations.begin(); defunct_i != defunct_locations.end(); defunct_i++) {
			FunctionLocation *d = *defunct_i;

			if(d->getUsers() == 0) {
				Code_free(d->getBase());
				delete d;
			} else {
				new_defunct.push_back(d);
			}
		}
	
		defunct_locations.clear();
		defunct_locations = new_defunct;

		for(FrameEntryListType::iterator entry_iter = live_frames.begin(); entry_iter != live_frames.end(); entry_iter++) {
			frame_entry_t *entry = *entry_iter;

			entry->old_frame = entry->frame;
			entry->frame = NULL;
		}
		live_frames.clear();

		FunctionListType new_live_functions;

		for(FunctionListType::iterator f_iter = live_functions.begin(); f_iter != live_functions.end(); f_iter++) {
			Function *f = *f_iter;

#ifdef LAZY_RELOCATION
			if(f->relocatedCount() > 3) {
				defunct_locations.push_back(f->getCurrentLocation());

				f->relocate();
				new_live_functions.push_back(f);

			} else {
				defunct_locations.push_back(f->getCurrentLocation());
				f->placeBreakpoint();
			}
#else
			defunct_locations.push_back(f->getCurrentLocation());
			f->relocate();
			new_live_functions.push_back(f);
#endif
		}

		live_functions.clear();
		live_functions = new_live_functions;
	
		set_timer(rerand_interval, rerandomize);
		rerand_interval = (rerand_interval * 5) / 4;
	}
}

int main(int argc, char **argv) {
#ifdef RERANDOMIZATION
	set_timer(rerand_interval, rerandomize);
#endif

#ifdef LAZY_RELOCATION
	struct sigaction sa;
	sa.sa_sigaction = &trap;
	sa.sa_flags = SA_SIGINFO;

	sigaction(SIGTRAP, &sa, NULL);
#endif

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

