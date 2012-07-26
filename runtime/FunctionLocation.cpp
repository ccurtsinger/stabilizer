//
//  FunctionLocation.cpp
//  stabilizer2
//
//  Created by Charlie Curtsinger on 9/13/11.
//  Copyright 2011 University of Massachusetts. All rights reserved.
//

#include <string.h>
#include <stdio.h>

#if defined(__POWERPC__)
#include <asm/cachectl.h>
#endif

#include "Global.h"
#include "Function.h"
#include "FunctionLocation.h"
#include "Util.h"

namespace stabilizer {

	FunctionLocation::FunctionLocation(Function *f) : function(f), base(f->getBase()), defunctCount(0) {}

	FunctionLocation::FunctionLocation(Function *f, void* b, void* alloc_b) : function(f), base(b), allocated_base(alloc_b), defunctCount(0) {
		FunctionLocation *current = function->getCurrentLocation();

		if(current->isOriginal()) {
			void **table = (void**)((intptr_t)base + function->getCodeSize());
			memcpy(base, current->getBase(), function->getCodeSize());
			
#if defined(__POWERPC__)
			cacheflush(base, function->getCodeSize(), BCACHE);
#endif

			// Set the users counter to zero
			*((size_t*)table) = 1;
			table++;

			// Set the function location object
			*((FunctionLocation**)table) = this;
			table++;

			for(void* p: function->getRefs()) {
				*table = p;
				table++;
			}
			
		} else {
			memcpy(base, current->getBase(), function->getTotalSize());
			void **table = (void**)((intptr_t)base + function->getCodeSize());
			*((size_t*)table) = 1;
			table++;
			*((FunctionLocation**)table) = this;
		}
	}

	void FunctionLocation::decrementUsers() {
		void **table = (void**)((intptr_t)base + function->getCodeSize());
		*((size_t*)table) = getUsers()-1;
	}

	size_t FunctionLocation::getUsers() {
		DEBUG("Checking users for %s at %p", function->getName(), getBase());

		size_t *users_ptr = (size_t*)((intptr_t)getBase() + function->getCodeSize());
		return *users_ptr;
	}
	
	bool FunctionLocation::isOriginal() {
		return this->base == function->getBase();
	}
}
