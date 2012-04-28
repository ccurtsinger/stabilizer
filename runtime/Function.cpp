//
//  Function.cpp
//  stabilizer2
//
//  Created by Charlie Curtsinger on 9/13/11.
//  Copyright 2011 University of Massachusetts. All rights reserved.
//
#include "Global.h"
#include "Function.h"
#include "FunctionLocation.h"
#include "Jump.h"
#include "Util.h"
#include "Heaps.h"

#include <sys/mman.h>

using namespace std;

namespace stabilizer {

	Function::Function(struct fn_info *info, GlobalMapType *globals) : name(info->name), base(info->base), limit(info->limit) {
		void **p = info->refs;
		while(*p != NULL) {
			refs.push_back(*p);
			p++;
		}

		this->globals = globals;

		mprotect(ALIGN_DOWN(getBase(), PAGESIZE), 2*PAGESIZE, PROT_READ | PROT_WRITE | PROT_EXEC);

		current_location = new FunctionLocation(this);
		relocated_count = 0;
	}

	FunctionLocation* Function::relocate() {
		relocated_count++;

		DEBUG("Relocating %s", getName());
		void *new_base = Code_malloc(getTotalSize());
	
		FunctionLocation *new_l = new FunctionLocation(this, new_base);
	
		new(getBase()) Jump(new_base);
	
		if(!current_location->isOriginal()) {
			current_location->decrementUsers();
		}
	
		current_location = new_l;

		DEBUG("Relocated %s: \n      [%p .. %p] -> [%p .. %p]",
			  name,
			  getBase(),
			  (void*)((intptr_t)getBase() + getCodeSize()),
			  new_l->getBase(),
			  (void*)((intptr_t)new_l->getBase() + getCodeSize())
		);
	
		return new_l;
	}
}
