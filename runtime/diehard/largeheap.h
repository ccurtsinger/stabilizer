#ifndef _LARGEHEAP_H_
#define _LARGEHEAP_H_

#include <assert.h>

namespace HL {}

#include "checkpoweroftwo.h"
#include "staticlog.h"
#include "myhashmap.h"
#include "bumpalloc.h"
#include "freelistheap.h"
#include "cpuinfo.h"

using namespace HL;

template <class Mapper>
class LargeHeap {
public:

  enum { Alignment = Mapper::Alignment };

  void * malloc (size_t sz) {
    void * ptr = Mapper::map (sz);
    set (ptr, sz);
    return ptr;
  }

  bool free (void * ptr) {
    // If we allocated this object, free it.
    size_t sz = get(ptr);
    if (sz > 0) {
      Mapper::unmap (ptr, sz);
      clear (ptr);
      return true;
    } else {
      return false;
    }
  }

  size_t getSize (void * ptr) {
    size_t s = get(ptr);
    return s;
  }

private:

  template <class TheMapper>
  class MapAlloc {
  public:
    void * malloc (size_t sz) {
      void * ptr = TheMapper::map (sz);
      return ptr;
    }
  };

  // The heap from which memory comes for the Map's purposes.
  // Objects come from chunks via mmap, and we manage these with a free list.
  class SourceHeap :
  public HL::FreelistHeap<BumpAlloc<65536, MapAlloc<Mapper> > > { };

  /// The map type, with all the pieces in place.
  typedef MyHashMap<void *, size_t, SourceHeap> mapType;

  mapType _objectSize;

  inline size_t get (void * ptr) {
    size_t sz = _objectSize.get (ptr);
    //    printf ("getting! %x = %d\n", ptr, sz);
    return sz;
  }
  
  inline void set (void * ptr, size_t sz) {
    //    printf ("setting! %x = %d\n", ptr, sz);
    // Initialize a range with the actual size.
    size_t currSize = sz;
    int iterations = (sz + CPUInfo::PageSize - 1) / CPUInfo::PageSize;
    for (int i = 0; i < iterations; i++) {
      _objectSize.set ((char *) ptr + i * CPUInfo::PageSize, currSize);
      currSize -= CPUInfo::PageSize;
    }
  }
  
  inline void clear (void * ptr) {
    size_t sz = get (ptr);
    int iterations = (sz + CPUInfo::PageSize - 1) / CPUInfo::PageSize;
    for (int i = 0; i < iterations; i++) {
      _objectSize.erase ((void *) ((char *) ptr + i * CPUInfo::PageSize));
    }
  }

};


#endif
