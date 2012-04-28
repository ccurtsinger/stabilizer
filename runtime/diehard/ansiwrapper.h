/* -*- C++ -*- */

#ifndef _ANSIWRAPPER_H_
#define _ANSIWRAPPER_H_

#include <stdlib.h>
#include <cassert>
#include <cstring>

#include "gcd.h"
#include "sassert.h"

//#include <cstdio>

/*
 * @class ANSIWrapper
 * @brief Provide ANSI C behavior for malloc & free.
 *
 * Implements all prescribed ANSI behavior, including zero-sized
 * requests & aligned request sizes to a double word (or long word).
 */


#include <cstdio>
using namespace std;

namespace HL {

template <class SuperHeap>
class ANSIWrapper : public SuperHeap {

public:

#if defined(__LP64__) || defined(_LP64) || defined(__APPLE__) || defined(_WIN64)
  enum { MinSize = 16 };
  enum { Alignment = 16 };
#else
  enum { MinSize   = 8 };
  enum { Alignment = 8 };
#endif

  ANSIWrapper() {
    sassert<(gcd<SuperHeap::Alignment, Alignment>::value == Alignment)> checkAlignment;
    checkAlignment = checkAlignment;
  }

  inline void * malloc (size_t sz) {
    if (sz < MinSize) {
      sz = MinSize;
    }
    void * ptr = SuperHeap::malloc (sz);
    assert ((size_t) ptr % Alignment == 0);
    return ptr;
  }
 
  inline void free (void * ptr) {
    if (ptr != 0) {
      SuperHeap::free (ptr);
    }
  }

  inline void * calloc (const size_t s1, const size_t s2) {
    char * ptr = (char *) malloc (s1 * s2);
    if (ptr) {
      memset (ptr, 0, s1 * s2);
    }
    return (void *) ptr;
  }
  
  inline void * realloc (void * ptr, const size_t sz) {
    if (ptr == 0) {
      return malloc (sz);
    }
    if (sz == 0) {
      free (ptr);
      return 0;
    }

    size_t objSize = getSize (ptr);
    if (objSize == sz) {
      return ptr;
    }

    // Allocate a new block of size sz.
    void * buf = malloc (sz);

    // Copy the contents of the original object
    // up to the size of the new block.

    size_t minSize = (objSize < sz) ? objSize : sz;
    if (buf) {
      memcpy (buf, ptr, minSize);
    }

    // Free the old block.
    free (ptr);
    return buf;
  }
  
  inline size_t getSize (void * ptr) {
    if (ptr) {
      return SuperHeap::getSize (ptr);
    } else {
      return 0;
    }
  }

private:
  inline static size_t align (size_t sz) {
    return (sz + (Alignment - 1)) & ~(Alignment - 1);
  }
};

}

#endif
