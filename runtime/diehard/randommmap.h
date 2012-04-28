// -*- C++ -*-

#ifndef RANDOMMMAP_H_
#define RANDOMMMAP_H_

#include "mmapheap.h"
#include "mmapwrapper.h"
#include "madvisewrapper.h"
#include "mwc64.h"
// #include "randomnumbergenerator.h"


class RandomMmap {
public:

  RandomMmap()
  {
    unsigned long long bytes = CPUInfo::PageSize * (unsigned long long) PAGES;
    // Get a giant chunk of memory.
    _pages = (void *) (MmapWrapper::map (bytes));
    if (_pages == NULL) {
      // Map failed!
      abort();
    }
    // Tell the OS that it's going to be randomly accessed.
    MadviseWrapper::random (_pages, bytes);
    // Initialize the bitmap.
    _bitmap.reserve (PAGES);
  }

  void * map (size_t sz) {
    unsigned int npages = (sz + CPUInfo::PageSize - 1) / CPUInfo::PageSize;
    // Randomly probe until we find a run of free pages.
    unsigned long index;
    while (true) {
      index = _rng.next() & (PAGES - 1);

      // If the chosen index is too far to the end (so it would
      // overrun the bitmap), try again.

      if (index + npages - 1 > PAGES) {
	continue;
      }

      bool foundRun = true;

      // Go through each page and try to set the bit for each one.

      for (unsigned int i = 0; i < npages; i++) {
	if (!_bitmap.tryToSet(index + i)) {
	  // If I tried to set this bit but it was already set,
	  // we did not find a run of enough free bits.
	  foundRun = false;
	  break;
	}
      }

      if (foundRun) {
	// Success!
	break;
      } else {
	// We did not find a long enough run.
	// Reset all the bits and try again.
	for (unsigned int i = 0; i < npages; i++) {
	  _bitmap.reset (index + i);
	}
      }
    }
    void * addr = (void *) ((char *) _pages + index * CPUInfo::PageSize);

    // Return it.
    return addr;
  }
  
  void unmap (void * ptr, size_t sz)
  {
    unsigned int npages = (sz + CPUInfo::PageSize - 1) / CPUInfo::PageSize;
    // Normalize the pointer (mask off the low-order bits).
    ptr = (void *) (((unsigned long) ptr) & ~(CPUInfo::PageSize-1));
    // Calculate its index.
    unsigned long index = ((unsigned long) ptr - (unsigned long) _pages) / CPUInfo::PageSize;
    // Mark the pages as unallocated.
    for (unsigned int i = 0; i < npages; i++) {
      _bitmap.reset (index + i);
    }
  }

private:
  
  enum { BITS = 32 - StaticLog<CPUInfo::PageSize>::value }; // size of address space, minus bits for pages.
  enum { PAGES = (1ULL << BITS) };
  
  MWC64 _rng;
  BitMap<MmapHeap> _bitmap;
  void * _pages;
  
};

#endif
