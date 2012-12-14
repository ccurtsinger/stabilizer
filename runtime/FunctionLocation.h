#if !defined(RUNTIME_FUNCTIONLOCATION_H)
#define RUNTIME_FUNCTIONLOCATION_H

#include "Heap.h"

struct Function;

struct FunctionLocation {
private:
	Function* _function;	//< The source function for this location
	void* _codeBase;		//< The base address of this function location

public:
	inline FunctionLocation(Function* function, void* codeBase) {
		this->_function = function;
		this->_codeBase = codeBase;
	}
	
	inline ~FunctionLocation() {
		getCodeHeap()->free(_codeBase);
	}
	
	inline void* getCodeBase() {
		return _codeBase;
	}
	
	inline intptr_t getOffset(void* p) {
		return (uintptr_t)p - (uintptr_t)_codeBase;
	}
};

#endif
