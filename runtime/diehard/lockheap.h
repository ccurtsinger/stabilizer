// -*- C++ -*- 

#ifndef _LOCKHEAP_H_
#define _LOCKHEAP_H_

#include <string.h>
#include "lock.h"

template <class SuperHeap>
class LockHeap : public SuperHeap {
public:

  inline void * malloc (size_t sz) {
    lock ();
    void * ptr = SuperHeap::malloc (sz);
    unlock ();
    return ptr;
  }

  inline void free (void * ptr) {
    lock();
    SuperHeap::free (ptr);
    unlock();
  }

  inline size_t getSize (void * ptr) {
    lock();
    size_t sz = SuperHeap::getSize (ptr);
    unlock();
    return sz;
  }

  // private:

  inline void lock (void) {
    _lock.lock();
  }

  inline void unlock (void) {
    _lock.unlock();
  }

private:

  Lock _lock;

};

#endif
