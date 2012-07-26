//
//  Metadata.h
//  stabilizer2
//
//  Created by Charlie Curtsinger on 9/23/11.
//  Copyright 2011 University of Massachusetts. All rights reserved.
//

#ifndef stabilizer2_Metadata_h
#define stabilizer2_Metadata_h

#include "Heaps.h"

#include <memory>
#include <limits>

// Class that all stabilizer metadata types must inherit from
class Metadata {
public:
	inline static void* operator new(size_t sz) {
		return MD_malloc(sz);
	}
	
	inline static void operator delete(void *p) {
		MD_free(p);
	}
};

// STL Allocator for the metadata heap
template<class T>
class MDAllocator {
public:
	// type definitions
	typedef T        value_type;
	typedef T*       pointer;
	typedef const T* const_pointer;
	typedef T&       reference;
	typedef const T& const_reference;
	typedef std::size_t    size_type;
	typedef std::ptrdiff_t difference_type;
	
	// rebind allocator to type U
	template <class U>
	struct rebind {
		typedef MDAllocator<U> other;
	};
	
	// return address of values
	pointer address (reference value) const {
		return &value;
	}
	const_pointer address (const_reference value) const {
		return &value;
	}
	
	const MDAllocator() throw() {}
	
	MDAllocator(const MDAllocator&) throw() {}
	
	template <class U>
	MDAllocator (const MDAllocator<U>&) throw() {}
	
	~MDAllocator() throw() {}
	
	// return maximum number of elements that can be allocated
	size_type max_size () const throw() {
		return std::numeric_limits<std::size_t>::max() / sizeof(T);
	}
	
	// allocate but don't initialize num elements of type T
	pointer allocate (size_type num, const void* = 0) {
		return (pointer)MD_malloc(num*sizeof(T));
	}
	
	// initialize elements of allocated storage p with value value
	void construct (pointer p, const T& value) {
		// initialize memory with placement new
		new((void*)p)T(value);
	}
	
	// destroy elements of initialized storage p
	void destroy (pointer p) {
		// destroy objects by calling their destructor
		p->~T();
	}
	
	// deallocate storage p of deleted elements
	void deallocate (pointer p, size_type num) {
		MD_free((void*)p);
	}
};

#endif
