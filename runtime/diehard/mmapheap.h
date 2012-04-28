// -*- C++ -*-

#ifndef MMAPALLOC_H_
#define MMAPALLOC_H_

#include <stdio.h>

#include "mmapwrapper.h"

/**
 * @class MmapHeap
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 */

class MmapHeap {

private:

  union Header {
    size_t size;
    char buf[16]; // Force 16-byte alignment.
  };

public:
  
  enum { Alignment = gcd<sizeof(Header), HL::MmapWrapper::Alignment>::value };

  virtual ~MmapHeap (void) {}

  static void * malloc (size_t sz) {
    Header * h = (Header *) HL::MmapWrapper::map (sz + sizeof(Header));
    h->size = sz;
    return (void *) (h + 1);
  }

  static size_t getSize (void * ptr) {
    Header * h = (Header *) ptr - 1;
    return h->size;
  }

  static void free (void * ptr) {
    Header * h = (Header *) ptr - 1;
    HL::MmapWrapper::unmap (h, h->size + sizeof(Header));
  }

};

#endif
