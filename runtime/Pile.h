#ifndef PILE_H
#define	PILE_H

#include <set>

#include "Heap.h"

using namespace std;

class Pile {
private:
	class Object {
	private:
		void* _base;
		size_t _sz;
	
	public:
		Object(void* base, size_t sz) : _base(base), _sz(sz) {}
		
		~Object() {
			getCodeHeap()->free(_base);
		}
		
		bool contains(uintptr_t p) {
			uintptr_t b = (uintptr_t)_base;
			uintptr_t l = b + _sz;
			
			return b <= p && p < l;
		}
	};
	
	static set<Object*>& getObjects() {
		static set<Object*> _objects = set<Object*>();
		return _objects;
	}
	
	static set<Object*>& getMarkedObjects() {
		static set<Object*> _markedObjects = set<Object*>();
		return _markedObjects;
	}
	
public:
	static void add(void* p, size_t sz) {
		Object* o = new Object(p, sz);
		getObjects().insert(o);
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

