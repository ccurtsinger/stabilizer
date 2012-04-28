// -*- C++ -*-

#ifndef MWC64_H_
#define MWC64_H_

#include <stdint.h>

#include "realrandomvalue.h"

class MWC64 {

  unsigned long long x, c, t;

  void init (unsigned long long seed1, unsigned long long seed2)
  {
    x = seed1;
    x <<= 32;
    x += seed2;
    c = 123456123456123456ULL;
  }

  unsigned long long MWC() {
    t = (x << 58) + c;
    c = x >> 6;
    x += t;
    c += (x < t);
    return x;
  }

public:
  
  MWC64()
  {
    unsigned int a = RealRandomValue::value();
    unsigned int b = RealRandomValue::value();
    init (a, b);
  }
  
  MWC64 (unsigned long long seed1, unsigned long long seed2)
  {
    init (seed1, seed2);
  }
  
  inline unsigned long long next()
  {
    return MWC();
  }

};

#endif
