// -*- C++ -*-

/**
 * @file   randomminiheap.h
 * @brief  Randomly allocates a particular object size in a range of memory.
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 *
 * Copyright (C) 2006 Emery Berger, University of Massachusetts Amherst
 */

#ifndef _RANDOMMINIHEAP_H_
#define _RANDOMMINIHEAP_H_

#include <assert.h>

extern "C" void reportDoubleFreeError (void);
extern "C" void reportInvalidFreeError (void);
extern "C" void reportOverflowError (void);


#include "bitmap.h"
#include "check.h"
#include "checkpoweroftwo.h"
#include "diefast.h"
#include "madvisewrapper.h"
#include "modulo.h"
#include "randomnumbergenerator.h"
#include "sassert.h"
#include "staticlog.h"
#include "threadlocal.h"

class RandomMiniHeapBase {
public:

  virtual void * malloc (size_t) = 0; //  { abort(); return 0; }
  virtual bool free (void *) = 0; // { abort(); return true; }
  virtual size_t getSize (void *) = 0; // { abort(); return 0; }
  virtual void activate (void) = 0; // { abort(); }
  virtual ~RandomMiniHeapBase () { abort(); }
};


/**
 * @class RandomMiniHeap
 * @brief Randomly allocates objects of a given size.
 * @param Numerator the heap multiplier numerator.
 * @param Denominator the heap multiplier denominator.
 * @param ObjectSize the object size managed by this heap.
 * @sa    RandomHeap
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 **/
template <int Numerator,
	  int Denominator,
	  unsigned long ObjectSize,
	  unsigned long NObjects,
	  class Allocator,
	  bool DieFastOn>
class RandomMiniHeap : public RandomMiniHeapBase {

  /// Check values for sanity checking.
  enum { CHECK1 = 0xEEDDCCBB, CHECK2 = 0xBADA0101 };

  /// A convenience struct.
  typedef struct {
    char obj[ObjectSize];
  } ObjectStruct;

  friend class Check<RandomMiniHeap *>;


public:

  typedef RandomMiniHeapBase SuperHeap;

  RandomMiniHeap (void)
    : _check1 ((size_t) CHECK1),
      _freedValue (((RandomNumberGenerator *) _random)->next() | 1), // Enforce invalid pointer value.
      _miniHeap (NULL),
      _isHeapIntact (true),
      _check2 ((size_t) CHECK2)
  {
    //    printf ("freed value = %ld\n", _freedValue);
    //    printf ("rng = %p\n", rng);

    Check<RandomMiniHeap *> sanity (this);

    /// Some sanity checking.
    CheckPowerOfTwo<ObjectSize>	_SizeIsPowerOfTwo;

    _SizeIsPowerOfTwo = _SizeIsPowerOfTwo; // to prevent warnings
  }

  bool isIntact (void) const {
    return _isHeapIntact;
  }

  /// @return an allocated object of size ObjectSize
  /// @param sz   requested object size
  /// @note May return NULL even though there is free space.
  inline void * malloc (size_t sz)
  {
    Check<RandomMiniHeap *> sanity (this);

    sz = sz; // to prevent warnings

    // Ensure size is reasonable.
    assert (sz <= ObjectSize);

    void * ptr = NULL;

    // Try to allocate an object from the bitmap.
    unsigned int index = (unsigned int) modulo<NObjects> (((RandomNumberGenerator *) _random)->next());

    bool didMalloc = _miniHeapBitmap.tryToSet (index);

    if (!didMalloc) {
      return NULL;
    }

    // Get the address of the indexed object.
    assert ((unsigned long) index < NObjects);
    ptr = getObject (index);
    
    if (DieFastOn) {
      // Check to see if this object was overflowed.
      if (DieFast::checkNot (ptr, ObjectSize, _freedValue)) {
	_isHeapIntact = false;
	reportOverflowError();
      }
    }

    assert (getSize(ptr) >= sz);
    assert (getSize(ptr) == ObjectSize);

    return ptr;
  }


  /// @return the space remaining from this point in this object
  /// @nb Returns zero if this object is not managed by this heap.
  inline size_t getSize (void * ptr) {
    Check<RandomMiniHeap *> sanity (this);

    if (!inBounds(ptr)) {
      return 0;
    }

    // Compute offset corresponding to the pointer.
    size_t offset = computeOffset (ptr);

    // Return the space remaining in the object from this point.
    size_t remainingSize =     
      ObjectSize - modulo<ObjectSize>(offset);

    return remainingSize;

  }


  /// @brief Relinquishes ownership of this pointer.
  /// @return true iff the object was on this heap and was freed by this call.
  inline bool free (void * ptr) {
    Check<RandomMiniHeap *> sanity (this);

    // Return false if the pointer is out of range.
    if (!inBounds(ptr)) {
      return false;
    }

    int index = computeIndex (ptr);
    assert ((index >= 0) && ((unsigned long) index < NObjects));

    bool didFree = true;

    // Reset the appropriate bit in the bitmap.
    if (_miniHeapBitmap.reset (index)) {
      // We actually reset the bit, so this was not a double free.
      if (DieFastOn) {
	checkOverflowError (ptr, index);
	// Trash the object.
	DieFast::fill (ptr, ObjectSize, _freedValue);
      }
    } else {
      reportDoubleFreeError();
      didFree = false;
    }
    return didFree;
  }

private:


  /// @brief Activates the heap, making it ready for allocations.
  NO_INLINE void activate (void) {
    if (_miniHeap == NULL) {
      // Go get memory for the heap and the bitmap, making it ready
      // for allocations.
      _miniHeap = (char *)
	Allocator::malloc (NObjects * ObjectSize);
      // Inform the OS that these pages will be accessed randomly.
      MadviseWrapper::random (_miniHeap, NObjects * ObjectSize);
      if (_miniHeap) {
	_miniHeapBitmap.reserve (NObjects);
	if (DieFastOn) {
	  DieFast::fill (_miniHeap, NObjects * ObjectSize, _freedValue);
	}

      } else {
	assert (0);
      }
    }
  }

  // Disable copying and assignment.
  RandomMiniHeap (const RandomMiniHeap&);
  RandomMiniHeap& operator= (const RandomMiniHeap&);

  /// Sanity check.
  void check (void) const {
    assert ((_check1 == CHECK1) &&
	    (_check2 == CHECK2));
  }

  /// @return the object at the given index.
  inline void * getObject (unsigned int index) const {
    assert ((unsigned long) index < NObjects);
    assert (_miniHeap != NULL);
    return (void *) &((ObjectStruct *) _miniHeap)[index];
  }

  /// @return the index corresponding to the given object.
  inline int computeIndex (void * ptr) const {
    assert (inBounds(ptr));
    size_t offset = computeOffset (ptr);
    if (IsPowerOfTwo<ObjectSize>::value) {
      return (int) (offset >> StaticLog<ObjectSize>::value);
    } else {
      return (int) (offset / ObjectSize);
    }
  }

  /// @return the distance of the object from the start of the heap.
  inline size_t computeOffset (void * ptr) const {
    assert (inBounds(ptr));
    size_t offset = ((size_t) ptr - (size_t) _miniHeap);
    return offset;
  }


  /// @brief Checks if the predecessor or successor have been overflowed.
  void checkOverflowError (void * ptr, unsigned int index)
  {
    // Check predecessor.
    if (!_miniHeapBitmap.isSet (index - 1)) {
      void * p = (void *) (((ObjectStruct *) ptr) - 1);
      if (DieFast::checkNot (p, ObjectSize, _freedValue)) {
	_isHeapIntact = false;
	reportOverflowError();
      }
    }
    // Check successor.
    if ((index < (NObjects - 1)) &&
	(!_miniHeapBitmap.isSet (index + 1))) {
      void * p = (void *) (((ObjectStruct *) ptr) + 1);
      if (DieFast::checkNot (p, ObjectSize, _freedValue)) {
	_isHeapIntact = false;
	reportOverflowError();
      }
    }
  }

  /// @return true iff the index is invalid for this heap.
  inline bool inBounds (void * ptr) const {
    if ((ptr < _miniHeap) || (ptr >= _miniHeap + NObjects * ObjectSize)
	|| (_miniHeap == NULL)) {
      return false;
    }
    return true;
  }

  /// @return true iff heap is currently active.
  inline bool isActivated (void) const {
    return (_miniHeap != NULL);
  }

  /// Cache-padded lock structure.
  class MyLock {
  private:
    enum { CACHE_LINE_SIZE = 128 };
    
    Lock _lock;
    char _dummy[CACHE_LINE_SIZE - (sizeof(Lock) % CACHE_LINE_SIZE)];
    
  public:
    void lock() {
      _lock.lock();
    }
    
    void unlock() {
      _lock.unlock();
    }
  };

  /// Sanity check value.
  const size_t _check1;

  /// A local random number generator.
  threadlocal<RandomNumberGenerator> _random;
  
  /// A random value used to overwrite freed space for debugging (with DieFast).
  const size_t _freedValue;

  /// The bitmap for this heap.
  BitMap<Allocator> _miniHeapBitmap;

  /// The heap pointer.
  char * _miniHeap;

  /// True iff the heap is intact (and DieFastOn is true).
  bool _isHeapIntact;

  /// Sanity check value.
  const size_t _check2;

};


#endif

