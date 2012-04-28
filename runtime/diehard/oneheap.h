#ifndef _ONEHEAP_H_
#define _ONEHEAP_H_

#include "singleton.h"

template <class TheHeap>
class OneHeap : public singleton<TheHeap> {
public:

  enum { Alignment = TheHeap::Alignment };

  static inline void * malloc (size_t sz) {
    return singleton<TheHeap>::getInstance().malloc (sz);
  }

  static inline bool free (void * ptr) {
    return singleton<TheHeap>::getInstance().free (ptr);
  }

  static inline size_t getSize (void * ptr) {
    return singleton<TheHeap>::getInstance().getSize (ptr);
  }
};


#endif
