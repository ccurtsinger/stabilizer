//
//  Heaps.h
//  stabilizer2
//
//  Created by Charlie Curtsinger on 9/24/11.
//  Copyright 2011 University of Massachusetts. All rights reserved.
//

#ifndef stabilizer2_Heaps_h
#define stabilizer2_Heaps_h

#include <stdlib.h>

void* MD_malloc(size_t sz);
void MD_free(void *p);

void* Code_malloc(size_t sz);
void Code_free(void *p);

extern "C" {
	void* DH_malloc(size_t sz);
	void* DH_calloc(size_t n, size_t sz);
	void* DH_realloc(void *ptr, size_t sz);
	void  DH_free(void *p);
}

#endif
