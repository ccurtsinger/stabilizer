#if !defined(RUNTIME_MMAPSOURCE_H)
#define RUNTIME_MMAPSOURCE_H

#include "Util.h"

template<int Prot, int Flags> class MMapSource {
private:
	bool _exhausted32;
	
public:
	enum { Alignment = PAGESIZE };

	MMapSource() {
		_exhausted32 = false;
	}
	
	inline void* malloc(size_t sz) {
		void* ptr;
		
		if(Flags & MAP_32BIT) {
			// If we haven't exhausted the 32 bit pages
			if(!_exhausted32) {
				ptr = mmap(NULL, sz, Prot, Flags, -1, 0);
				
				if(ptr != MAP_FAILED) {
					return ptr;
				} else {
					_exhausted32 = true;
				}
			}
		}
		
		// Try the map without the MAP_32BIT flag set
		ptr = mmap(NULL, sz, Prot, Flags & ~MAP_32BIT, -1, 0);
		
		if(ptr == MAP_FAILED) {
			ptr = NULL;
		}
		
		return ptr;
	}
};

#endif
