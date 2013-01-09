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
private:
	void* _pool;

public:
	enum { Alignment = 16 };
	
	TLSFLayer() : _pool(NULL) {}
	
	inline void* getPool() {
		if(_pool == NULL) {
			_pool = map();
			init_memory_pool(MapSize, _pool);
		}
		
		return _pool;
	}
	
	static inline void* map() {
		void* p = mmap(NULL, MapSize, Prot, Flags, -1, 0);

		/*if((Flags & MAP_32BIT) && p == MAP_FAILED) {
			p = mmap(NULL, MapSize, Prot, Flags & ~MAP_32BIT, -1, 0);
		}*/

		if(p == MAP_FAILED) {
			fprintf(stderr, "Out of memory!\n");
			abort();
		}
		return p;
	}
	
	inline void expand(size_t sz) {
		size_t heapsize = 0;
		while(heapsize < sz) {
			heapsize = add_new_area(map(), MapSize, getPool());
		}
	}
	
	inline void* malloc(size_t sz) {
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
	
	inline void free(void* p) {
		free_ex(p, getPool());
	}
	
	inline size_t getSize(void* p) {
		return get_object_size_ex(p, getPool());
	}
};

#endif
