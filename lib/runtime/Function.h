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

#include "list.h"

using namespace std;

namespace stabilizer {

	class Function;
	class FunctionLocation;

	struct fn_info {
		char *name;
		void *base;
		void *limit;
		void **refs;
	};

	struct fn_header {
		uint8_t breakpoint;
		uint8_t pad[63];
		Function *obj;
	};

	class Function : public Metadata {
	private:
		char *name;
		void *base;
		void *limit;
		size_t relocated_count;

		struct fn_header header;

		list<void*> refs;
		FunctionLocation *current_location;

	public:
		Function(struct fn_info *info);
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
		
		inline list<void*> getRefs() {
			return refs;
		}
	};
}

#endif
