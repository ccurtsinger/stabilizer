/* -*- C++ -*- */

#ifndef _FREELISTHEAP_H_
#define _FREELISTHEAP_H_

/**
 * @class FreelistHeap
 * @brief Manage freed memory on a linked list.
 * @warning This is for one "size class" only.
 * 
 * Note that the linked list is threaded through the freed objects,
 * meaning that such objects must be at least the size of a pointer.
 */

#include "freesllist.h"
#include <assert.h>

#ifndef NULL
#define NULL 0
#endif

namespace HL {

template <class SuperHeap>
class FreelistHeap : public SuperHeap {
public:
  
  inline void * malloc (size_t sz) {
    // Check the free list first.
    void * ptr = _freelist.get();
    // If it's empty, get more memory;
    // otherwise, advance the free list pointer.
    if (ptr == 0) {
      ptr = SuperHeap::malloc (sz);
    }
    return ptr;
  }
  
  inline void free (void * ptr) {
    if (ptr == 0) {
      return;
    }
    _freelist.insert (ptr);
  }

  inline void clear (void) {
    void * ptr;
    while (ptr = _freelist.get()) {
      SuperHeap::free (ptr);
    }
  }

private:

  FreeSLList _freelist;

};

}

#endif
