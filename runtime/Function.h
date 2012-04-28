//
//  Function.h
//  stabilizer2
//
//  Created by Charlie Curtsinger on 9/13/11.
//  Copyright 2011 University of Massachusetts. All rights reserved.
//

#ifndef stabilizer2_Function_h
#define stabilizer2_Function_h

#include <stdio.h>
#include <sys/mman.h>
#include <stdint.h>

#include "Metadata.h"
#include "Global.h"
#include "Heaps.h"

#include <vector>

using namespace std;

namespace stabilizer {

	class Function;
	class FunctionLocation;

	typedef vector<void*, MDAllocator<void*> > PointerListType;

	typedef vector<Function*, MDAllocator<Function*> > FunctionListType;

	typedef vector<FunctionLocation*, MDAllocator<FunctionLocation*> > FunctionLocationListType;

	struct fn_info {
		char *name;
		void *base;
		void *limit;
		void **refs;
	};

	struct fn_header {
		uint8_t breakpoint;
		Function *obj;
	};

	class Function : public Metadata {
	private:
		char *name;
		void *base;
		void *limit;
		size_t relocated_count;

		struct fn_header header;

		GlobalMapType *globals;
	
		PointerListType refs;

		FunctionLocation *current_location;

	public:
		Function(struct fn_info *info, GlobalMapType *globals);
		FunctionLocation* relocate();
	
		size_t relocatedCount() {
			return relocated_count;
		}
	
		void placeBreakpoint() {
			struct fn_header *h = (struct fn_header*)base;
			header = *h;
			
			h->breakpoint = 0xCC;
			h->obj = this;
		}
	
		void restoreHeader() {
			struct fn_header *h = (struct fn_header*)base;
			*h = header;
		}

		char* getName() {
			return name;
		}
		
		void* getBase() {
			return base;
		}

		inline GlobalMapType getGlobals() {
			return *globals;
		}

		inline size_t getCodeSize() {
			return (size_t)((uintptr_t)limit - (uintptr_t)base);
		}

		inline size_t getTableSize() {
			return sizeof(void*) * (refs.size() + 2);
		}

		inline size_t getTotalSize() {
			return getCodeSize() + getTableSize();
		}

		inline FunctionLocation* getCurrentLocation() {
			return current_location;
		}

		inline PointerListType::iterator refs_begin() {
			return refs.begin();
		}

		inline PointerListType::iterator refs_end() {
			return refs.end();
		}
	};
}

#endif
