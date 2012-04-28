// -*- C++ -*-

/**
 * @file   randomminiheap.h
 * @brief  Randomly allocates a particular object size in a range of memory.
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 *
 * Copyright (C) 2006-11 Emery Berger, University of Massachusetts Amherst
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
#include "modulo.h"
#include "randomnumbergenerator.h"
#include "sassert.h"
#include "staticlog.h"
#include "threadlocal.h"
#include "cpuinfo.h"

#include "mypagetable.h"

class RandomMiniHeapBase {
public:

  virtual void * malloc (size_t) = 0; // { abort(); return 0; }
  virtual bool free (void *) = 0; // { abort(); return true; }
  virtual size_t getSize (void *) = 0; // { abort(); return 0; }
  virtual void activate (void) = 0; // { abort(); }
  virtual ~RandomMiniHeapBase () {}
};


/**
 * @class RandomMiniHeap
 * @brief Randomly allocates objects of a given size.
 * @param Numerator the heap multiplier numerator.
 * @param Denominator the heap multiplier denominator.
 * @param ObjectSize the object size managed by this heap.
 * @param NObjects the number of objects in this heap.
 * @param Allocator the source heap for allocations.
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
  
  enum { NumPages = (NObjects * ObjectSize) / CPUInfo::PageSize };

  enum { ObjectsPerPage = StaticIf<(ObjectSize < CPUInfo::PageSize),
				    CPUInfo::PageSize / ObjectSize,
				    1>::value };

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
      _miniHeapMap (NULL),
      _isHeapIntact (true),
      _check2 ((size_t) CHECK2)
  {
    //    printf ("freed value = %ld\n", _freedValue);
    //    printf ("rng = %p\n", rng);

    Check<RandomMiniHeap *> sanity (this);

    // Some sanity checking: all these need to be powers of two.

    CheckPowerOfTwo<ObjectSize>	invariant1;
    invariant1 = invariant1; // to prevent warnings

    CheckPowerOfTwo<CPUInfo::PageSize> invariant2;
    invariant2 = invariant2;
    
    CheckPowerOfTwo<ObjectsPerPage> invariant3;
    invariant3 = invariant3;

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
    
    assert (index == computeIndex(ptr));
    
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

    size_t remainingSize;

    // Return the space remaining in the object from this point.
    if (ObjectSize <= CPUInfo::PageSize)
      remainingSize = ObjectSize - modulo<ObjectSize>(reinterpret_cast<uintptr_t>(ptr));
    else {
      uintptr_t start = (uintptr_t) _miniHeapMap[getPageIndex(ptr)];
      remainingSize = ObjectSize - ((uintptr_t) ptr - start);
    }

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

    unsigned int index = computeIndex (ptr);
    assert (((unsigned long) index < NObjects));

    bool didFree = true;

    // Reset the appropriate bit in the bitmap.
    if (_miniHeapBitmap.reset (index)) {
      // We actually reset the bit, so this was not a double free.
      if (!DieFastOn) {
	// Trash the object: REQUIRED for DieHarder.
	memset (ptr, 0, ObjectSize);
      } else {
	// Check for overflows into adjacent objects,
	// then fill the freed object with a known random value.
	checkOverflowError (ptr, index);
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
    if (_miniHeapMap == NULL) {
      // Compute the number of pointers to allocate (one per page or
      // large object).
      size_t numPointers = (ObjectSize <= CPUInfo::PageSize) ?
	(size_t) NumPages :
	NObjects;
      
      _miniHeapMap = (void **)
        Allocator::malloc (numPointers * sizeof(void*));
      
      if (_miniHeapMap) {
        _miniHeapBitmap.reserve (NObjects);

        for (unsigned int i = 0; i < numPointers; i++) {
          activatePage (i);
        }
      }
    }
  }

  /// @brief Activates the page or range of pages corresponding to the given index.
  inline void activatePage (unsigned int idx) {
    void * page;
    
    if (ObjectSize <= CPUInfo::PageSize) {
      page = MyPageTable::getInstance().allocatePage (this,idx);
    } else {
      page = MyPageTable::getInstance().allocatePageRange (this, idx, ObjectSize / CPUInfo::PageSize);
    }

    _miniHeapMap[idx] = page;
    
#if 0
    if (DieFastOn) {
      // Fill the contents with a known value.
      DieFast::fill (page, (ObjectSize < CPUInfo::PageSize) ?
		     CPUInfo::PageSize :
		     ObjectSize, _freedValue);
    }
#endif
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

    assert (_miniHeapMap != NULL);
    
    if (ObjectSize > CPUInfo::PageSize) {
      return _miniHeapMap[index];
    } else {
      unsigned int mapIdx = (index >> StaticLog<ObjectsPerPage>::value);
      return (void *) &((ObjectStruct *) _miniHeapMap[mapIdx])[index & (ObjectsPerPage-1)];
    }

  }

  /// @return the index corresponding to the given object.
  inline unsigned int computeIndex (void * ptr) const {
    assert (inBounds(ptr));
    unsigned int pageIdx = getPageIndex (ptr);
    
    if (ObjectsPerPage == 1) {
      return pageIdx;
    }

    unsigned long offset = ((unsigned long)(ptr) & (CPUInfo::PageSize-1));

    //    fprintf (stderr,"pidx = %d, offset = %ld\n",pageIdx,offset);
   
    if (IsPowerOfTwo<ObjectSize>::value) {
      unsigned int ret = (unsigned int) ((pageIdx * ObjectsPerPage) + 
					 (offset >> StaticLog<ObjectSize>::value));
      
      assert (ret < NObjects);
      return ret;
    } else {
      // We will never get here.
      assert (false);
    }
  }

  /// @brief Checks if the predecessor or successor have been overflowed.
  /// NOTE: Disabled since it currently does not take into account non-contiguity.
  void checkOverflowError (void * ptr, unsigned int index)
  {
    ptr = ptr;
    index = index;
#if 0 // FIX ME temporarily disabled.
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
#endif
  }

  /// @return true iff the index is invalid for this heap.
  inline bool inBounds (void * ptr) const {
    if (_miniHeapMap == NULL) {
      return false;
    }

    PageTableEntry * entry = MyPageTable::getInstance().getPageTableEntry (ptr);

    if (!entry) {
      return false;
    }
    return (entry->getHeap() == this);
  }

  /// @return true iff heap is currently active.
  inline bool isActivated (void) const {
    return (_miniHeapMap != NULL);
  }
  
  inline unsigned int getPageIndex (void * ptr) const {
    PageTableEntry * entry = MyPageTable::getInstance().getPageTableEntry (ptr);

    assert (entry != NULL);

    if (entry) {
      // EDB: is this actually necessary?
      // assert (entry->getHeap() == this);
      return entry->getPageIndex();
    }
   
    abort(); 
    return 0;
  }

  /// Sanity check value.
  const size_t _check1;

  /// A local random number generator.
  threadlocal<RandomNumberGenerator> _random;
  
  /// A random value used to overwrite freed space for debugging (with DieFast).
  const size_t _freedValue;

  /// The bitmap for this heap.
  BitMap<Allocator> _miniHeapBitmap;

  /// Sparse page pointer structure.
  void ** _miniHeapMap;

  /// True iff the heap is intact (and DieFastOn is true).
  bool _isHeapIntact;

  /// Sanity check value.
  const size_t _check2;

};


#endif

