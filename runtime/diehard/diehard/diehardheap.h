// -*- C++ -*-

/**
 * @file   DieHardHeap.h
 * @brief  Manages random heaps.
 * @sa     randomheap.h, randomminiheap.h
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 *
 * Copyright (C) 2006-11 Emery Berger, University of Massachusetts Amherst
 */


#ifndef _DIEHARDHEAP_H_
#define _DIEHARDHEAP_H_

#include <new>

#include "diefast.h"
#include "staticforloop.h"
#include "log2.h"
#include "platformspecific.h"
#include "realrandomvalue.h"
#include "randomheap.h"
#include "randomminiheap.h"
#include "sassert.h"
#include "staticlog.h"

template <int Numerator,
	  int Denominator,
	  int MaxSize,
	  bool DieFast>

class DieHardHeap {

public:

#if defined(__LP64__) || defined(_LP64) || defined(__APPLE__) || defined(_WIN64)
  enum { MinSize = 16 };
  enum { Alignment = 16 };
#else
  enum { MinSize   = 8 };
  enum { Alignment = 8 };
#endif

private:

  /// The number of size classes managed by this heap.
  enum { MAX_INDEX =
	 StaticLog<MaxSize>::value -
	 StaticLog<Alignment>::value + 1 };

public:

  enum { MAX_SIZE = MaxSize };
  
  DieHardHeap (void)
    : _localRandomValue (RealRandomValue::value())
  {
    // Check that there are no size dependencies to worry about.
    sassert<(sizeof(RandomHeap<Numerator, Denominator, Alignment, MaxSize, RandomMiniHeap, DieFast>)
	     == (sizeof(RandomHeap<Numerator, Denominator, 256 * Alignment, MaxSize, RandomMiniHeap, DieFast>)))>
      verifyNoSizeDependencies;

    // Check to make sure the size specified by MaxSize is correct.
    sassert<((1 << (MAX_INDEX-1)) * Alignment) == MaxSize>
      verifySizeFormulation;

    // avoiding warnings here
    verifyNoSizeDependencies = verifyNoSizeDependencies;
    verifySizeFormulation = verifySizeFormulation;

    // Warning: some crazy template meta-programming in the name of
    // efficiency below.

    // Statically declare MAX_INDEX heaps, each one containing objects
    // twice as large as the preceding one: the first one holds
    // Alignment, then the next holds objects of size
    // 2*Alignment, etc. See the Initializer class
    // below.
    StaticForLoop<0, MAX_INDEX, Initializer, void *>::run ((void *) _buf);
  }
  
  /// @brief Allocate an object of the requested size.
  /// @return such an object, or NULL.
  inline void * malloc (size_t sz) {
    // If the object request size is too big, just return NULL.
    if (sz > MaxSize) {
      return NULL;
    }
    if (sz < Alignment) {
      sz = Alignment;
    }
    
    // Compute the index corresponding to the size request, and
    // return an object allocated from that heap.
    int index = getIndex (sz);
    void * ptr = getHeap(index)->malloc (sz);
    
    if (DieFast) {
      // Fill with special value.
      size_t actualSize = getClassSize (index);
      DieFast::fill (ptr, actualSize, _localRandomValue);
    }
    
    return ptr;
  }
  
  
  /// @brief Relinquishes ownership of this pointer.
  /// @return true iff the object was on this heap.
  inline bool free (void * ptr) {
    // Go through the heap and try to free the object.
    // We assume that the common case is when objects are small,
    // so we check the smaller heaps first.
    for (int i = 0; i < MAX_INDEX; i++) {
      if (getHeap(i)->free (ptr))
	// Successfully freed.
	return true;
    }
    
    // If we get here, the object could be a "big" object.
    return false;
  }
  
  
  /// @return the space available from this point in the given object
  /// @note returns 0 if this object is not managed by this heap
  inline size_t getSize (void * ptr) const {
    // Iterate, from smallest to largest, checking for the given
    // object size.
    for (int i = 0; i < MAX_INDEX; i++) {
      size_t sz = getHeap(i)->getSize (ptr);
      if (sz != 0) {
	return sz;
      }
    }
    // If we get here, the object could be a "big" object. In any
    // event, we don't own it, so return 0.
    return 0;
  }
  
private:

 
  /// @return the maximum object size for the given index.
  static inline size_t getClassSize (int index) {
    assert (index >= 0);
    assert (index < MAX_INDEX);
    return (1 << index) * Alignment;
  }

  /// @return the index (size class) for the given size
  static inline int getIndex (size_t sz) {
    // Now compute the log.
    assert (sz >= Alignment);
    int index = log2(sz) - StaticLog<Alignment>::value;
    return index;
  }

  template <int index>
  class Initializer {
  public:
    static void run (void * buf) {
      new ((char *) buf + MINIHEAPSIZE * index)
	RandomHeap<Numerator,
	Denominator,
	(1 << index) * Alignment, // NB: = getClassSize(index)
	MaxSize,
        RandomMiniHeap,
	DieFast>();
    }
  };

  /// @return the heap corresponding to the given index.
  inline RandomHeapBase<Numerator, Denominator> * getHeap (int index) const {
    // Return the requested heap.
    assert (index >= 0);
    assert (index < MAX_INDEX);
    return (RandomHeapBase<Numerator, Denominator> *) &_buf[MINIHEAPSIZE * index];
  }

  enum { MINIHEAPSIZE = 
	 sizeof(RandomHeap<Numerator, Denominator, Alignment, MaxSize, RandomMiniHeap, DieFast>) };

  /// A random value used for detecting overflows (for DieFast).
  const size_t _localRandomValue;

  // The buffer that holds each RandomHeap.
  char _buf[MINIHEAPSIZE * MAX_INDEX];

};


#endif
