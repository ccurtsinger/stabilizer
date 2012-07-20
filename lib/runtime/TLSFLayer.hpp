#ifndef _TLSFLAYER_HPP_
#define _TLSFLAYER_HPP_

#include <stdio.h>
#include <sys/mman.h>

#include "Util.h"
#include "tlsf.h"

#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif

#ifndef MAP_32BIT
#define MAP_32BIT 0
#endif

#ifndef MAP_HUGETLB
#define MAP_HUGETLB 0
#endif

extern size_t get_object_size_ex (void * ptr, void * mem_pool);

template<size_t MapSize, int Prot, int Flags>
struct TLSFLayer {
	enum { Alignment = 16 };
	
	void* getPool() {
		static void* pool = NULL;
		if(pool == NULL) {
			pool = map();
			init_memory_pool(MapSize, pool);
		}
		return pool;
	}
	
	static void* map() {
		void* p = mmap(NULL, MapSize, Prot, Flags, -1, 0);
		if(p == MAP_FAILED) {
			fprintf(stderr, "Out of memory!\n");
			abort();
		}
		return p;
	}
	
	void expand(size_t sz) {
		size_t heapsize = 0;
		while(heapsize < sz) {
			heapsize = add_new_area(map(), MapSize, getPool());
		}
	}
	
	void* malloc(size_t sz) {
		void* p = malloc_ex(sz, getPool());
		if(p == NULL) {
			expand(sz);
			DEBUG("Malloc of size %lu requires expansion", sz);
			p = malloc_ex(sz, getPool());
			if(p == NULL) {
				fprintf(stderr, "TLSF pool refuses to expand!\n");
				abort();
			}
		}
		return p;
	}
	
	void free(void* p) {
		//free_ex(p, getPool());
	}
	
	size_t getSize(void* p) {
		return get_object_size_ex(p, getPool());
	}
};

#endif
