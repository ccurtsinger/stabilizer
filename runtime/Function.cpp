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
#include <stdio.h>

using namespace std;

#define ALIGN 128

namespace stabilizer {

	Function::Function(struct fn_info *info) : name(info->name), base(info->base), limit(info->limit) {
		void **p = info->refs;
		while(*p != NULL) {
			refs.append(*p);
			p++;
		}

		mprotect(ALIGN_DOWN(getBase(), PAGESIZE), 2*PAGESIZE, PROT_READ | PROT_WRITE | PROT_EXEC);

		current_location = new FunctionLocation(this);
		relocated_count = 0;
	}

	FunctionLocation* Function::relocate() {
		relocated_count++;

		DEBUG("Relocating %s", getName());
		void *new_base = Code_malloc(getTotalSize()+ALIGN);
		intptr_t base_p = (intptr_t)new_base;
		
		void *aligned_base = new_base;
		
		if((base_p & (ALIGN-1)) != 0) {
			aligned_base = (void*)(base_p + ALIGN - (base_p & (ALIGN-1)));
		}
	
		//fprintf(stderr, "Function allocated at %p, placed at %p\n", new_base, aligned_base);
	
		FunctionLocation *new_l = new FunctionLocation(this, aligned_base, new_base);
	
		new(getBase()) Jump(aligned_base);
	
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
