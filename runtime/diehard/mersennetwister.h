// -*- C++ -*-

#ifndef MERSENNETWISTER_H_
#define MERSENNETWISTER_H_

#if defined(_MSC_VER) && (_M_IX86_FP < 2)
#error "This class requires SSE2 support (i.e., compile with /arch:SSE2)."
#endif

#ifndef __SSE2__
#error "This class requires SSE2 support (i.e., compile with -msse2)."
#endif

#include <emmintrin.h>

#include "sfmersenne.h"

class MersenneTwister {
public:

  MersenneTwister (unsigned long seed1, unsigned long seed2)
    : _sf (seed1),
      _index (0)
  {
    _arr = _array32;
    _len = NUM;
    while ((unsigned long) _arr % 128 != 0) {
      _arr++;
      _len--;
    }
    while (_len % 4 != 0) {
      _len--;
    }

    assert (_len >= _sf.get_min_array_size32());
    refill();
  }

  inline unsigned int next (void) {
    if (_index == _len) {
      refill();
      _index = 0;
    }
    unsigned int ret = _arr[_index];
    ++_index;
    return ret;
  }

private:

  SFMersenne _sf;

  enum { NUM = 1024 };

  void refill() {
    assert (_len >= (19937 / 128 + 1) * 4);
    _sf.fill_array32 (_arr, _len);
  }

  uint32_t * _arr;
  unsigned int _len;
  unsigned int _index;

  union {
    uint32_t _array32[NUM];
    __m128i _dummy[NUM / 4];
  };

};


#endif
