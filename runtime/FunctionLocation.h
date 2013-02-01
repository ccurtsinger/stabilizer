#if !defined(RUNTIME_FUNCTIONLOCATION_H)
#define RUNTIME_FUNCTIONLOCATION_H

#include <set>

#include "MemRange.h"
#include "Function.h"

using namespace std;

struct FunctionLocation {
private:
    friend class Function;
    
    Function* _f;
    MemRange _memory;
    bool _defunct;
    bool _marked;
    
    static inline set<FunctionLocation*>& getRegistry() {
        static set<FunctionLocation*> _registry;
        return _registry;
    }
    
    static FunctionLocation* find(void* p) {
        for(set<FunctionLocation*>::iterator iter = getRegistry().begin(); iter != getRegistry().end(); iter++) {
            FunctionLocation* l = *iter;
            if(l->_memory.contains(p)) {
                return l;
            }
        }
        
        return NULL;
    }
    
public:
    FunctionLocation(Function* f) :  _f(f), _memory(getCodeHeap()->malloc(_f->getAllocationSize()), _f->getAllocationSize()) {
        if(_memory.base() == NULL) {
            perror("code malloc");
            ABORT("Couldn't allocate memory for function relocation");
        }
        
        _defunct = false;
        _marked = false;
        
        _f->copyTo(_memory.base());
        
        getRegistry().insert(this);
    }
    
    ~FunctionLocation() {
        getCodeHeap()->free(_memory.base());
    }
    
    /**
	 * \brief Allocate FunctionLocation objects on the randomized heap
	 * \arg sz The object size
	 */
	void* operator new(size_t sz) {
		return getDataHeap()->malloc(sz);
	}
	
	/**
	 * \brief Free allocated memory to the randomized heap
	 * \arg p The object base pointer
	 */
	void operator delete(void* p) {
		getDataHeap()->free(p);
	}
    
    void activate() {
        _f->forward(_memory.base());
    }
    
    void release() {
        _defunct = true;
    }
    
    void* getBase() {
        return _memory.base();
    }
    
    static void mark(void* p) {
        FunctionLocation* l = find(p);
        if(l != NULL) {
            l->_marked = true;
        }
    }
    
    static void sweep() {
        set<FunctionLocation*>::iterator iter = getRegistry().begin();
        
        while(iter != getRegistry().end()) {
            FunctionLocation* l = *iter;
            
            if(l->_defunct && !l->_marked) {
                getRegistry().erase(iter++);
                delete l;
            } else {
                l->_marked = false;
                iter++;
            }
        }
    }
    
    static void* adjust(void* p) {
        FunctionLocation* l = find(p);
        if(l != NULL) {
            size_t offset = l->_memory.offsetOf(p);
            return l->_f->_code.offsetIn(offset);
        } else {
            return p;
        }
    }
};

#endif
