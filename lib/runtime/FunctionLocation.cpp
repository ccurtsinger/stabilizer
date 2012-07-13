//
//  FunctionLocation.cpp
//  stabilizer2
//
//  Created by Charlie Curtsinger on 9/13/11.
//  Copyright 2011 University of Massachusetts. All rights reserved.
//

#include <string.h>
#include <stdio.h>

#include "Global.h"
#include "Function.h"
#include "FunctionLocation.h"
#include "Util.h"

namespace stabilizer {

	FunctionLocation::FunctionLocation(Function *f) : function(f), base(f->getBase()) {}

	FunctionLocation::FunctionLocation(Function *f, void *b) : function(f), base(b) {
		FunctionLocation *current = function->getCurrentLocation();

		if(current->isOriginal()) {
			void **table = (void**)((intptr_t)base + function->getCodeSize());
			memcpy(base, current->getBase(), function->getCodeSize());

			// Set the users counter to zero
			*((size_t*)table) = 1;
			table++;

			// Set the function location object
			*((FunctionLocation**)table) = this;
			table++;

			GlobalMapType g = f->getGlobals();
			for(PointerListType::iterator r = function->refs_begin(); r != function->refs_end(); r++) {
				void *p = *r;

				if(g.find(p) != g.end()) {
					p = g[p]->getRelocatedBase();
				}

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
