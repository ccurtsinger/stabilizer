#if !defined(RUNTIME_FUNCTION_H)
#define RUNTIME_FUNCTION_H

#include <string.h>
#include <sys/mman.h>

#include "Util.h"
#include "Jump.h"

struct Function {
private:
	void* _base;
	void* _limit;
	void* _relocationTable;
	size_t _tableSize;
	bool _adjacent;
	
	void* _currentBase;
	
	void forward() {
		void* jumpPageBase = (void*)ALIGN_DOWN(_base, PAGESIZE);
		void* jumpPageLimit = (void*)ALIGN_UP((uintptr_t)_base + sizeof(Jump), PAGESIZE);
		size_t jumpPageSize = (uintptr_t)jumpPageLimit - (uintptr_t)jumpPageBase;
		
		mprotect(jumpPageBase, jumpPageSize, PROT_READ | PROT_WRITE | PROT_EXEC);
		
		new(_base) Jump(_currentBase);
		
		flush_icache(_base, sizeof(Jump));
	}
	
public:
	Function(void* base, void* limit, void* relocationTable, size_t tableSize, bool adjacent) :
		_base(base), _limit(limit), _currentBase(base), _relocationTable(relocationTable),
		_tableSize(tableSize), _adjacent(adjacent) {}
	
	inline size_t codeSize() {
		return (uintptr_t)_limit - (uintptr_t)_base;
	}
	
	inline size_t tableSize() {
		return _tableSize;
	}
	
	inline void* originalBase() {
		return _base;
	}
	
	inline void* currentBase() {
		return _currentBase;
	}
	
	inline bool adjacentTable() {
		return _adjacent;
	}
	
	inline void* originalTable() {
		return _relocationTable;
	}
	
	inline void* currentTable() {
		if(adjacentTable()) {
			return (void*)((uintptr_t)_currentBase + codeSize());
			
		} else {
			return originalTable();
		}
	}
	
	inline size_t allocationSize() {
		size_t sz = codeSize();
		if(_adjacent) {
			sz += tableSize();
		}
		return sz;
	}
		
	void relocate() {
		_currentBase = mmap(NULL, (size_t)ALIGN_UP(allocationSize(), PAGESIZE), 
			PROT_READ | PROT_WRITE | PROT_EXEC,
			MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT, -1, 0);
		
		memcpy(_currentBase, _base, codeSize());
		
		if(adjacentTable()) {
			memcpy(currentTable(), originalTable(), tableSize());
		}
		
		forward();
	}
};

#endif
