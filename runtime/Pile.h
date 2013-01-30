#ifndef PILE_H
#define	PILE_H

#include <set>

#include "Heap.h"

using namespace std;

class Object {
private:
    void* _base;
    void* _real;
    size_t _sz;

public:
    Object(void* base, void* real, size_t sz) : _base(base), _real(real), _sz(sz) {}

    ~Object() {
        getCodeHeap()->free(_base);
    }

    bool contains(uintptr_t p) {
        uintptr_t b = (uintptr_t)_base;
        uintptr_t l = b + _sz;

        return b <= p && p < l;
    }

    void* adjust(void* p) {
        uintptr_t q = (uintptr_t)p;
        q -= (intptr_t)_base;
        q += (intptr_t)_real;
        return (void*)q;
    }
};

class Pile {
private:
	static set<Object*>& getObjects() {
		static set<Object*> _objects = set<Object*>();
		return _objects;
	}
	
	static set<Object*>& getMarkedObjects() {
		static set<Object*> _markedObjects = set<Object*>();
		return _markedObjects;
	}
	
public:
	static void add(void* p, void* real, size_t sz) {
		Object* o = new Object(p, real, sz);
		getObjects().insert(o);
	}
    
    static Object* find(void* p) {
        for(set<Object*>::iterator iter = getObjects().begin(); iter != getObjects().end(); iter++) {
			Object* o = *iter;
			if(o->contains((uintptr_t)p)) {
				return o;
			}
		}
        
        return NULL;
    }
	
	static void mark(void* p) {
		for(set<Object*>::iterator iter = getObjects().begin(); iter != getObjects().end(); iter++) {
			Object* o = *iter;
			if(o->contains((uintptr_t)p)) {
				getObjects().erase(iter);
				getMarkedObjects().insert(o);
				return;
			}
		}
	}
	
	static void sweep() {
		for(set<Object*>::iterator iter = getObjects().begin(); iter != getObjects().end(); iter++) {
			Object* o = *iter;
			delete o;
		}
		
		getObjects() = getMarkedObjects();
		getMarkedObjects() = set<Object*>();
	}
};

#endif	/* PILE_H */

