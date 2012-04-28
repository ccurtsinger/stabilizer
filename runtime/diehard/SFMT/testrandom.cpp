// g++ -fno-strict-aliasing -DMEXP=19937 -DHAVE_SSE2 -DNDEBUG -msse2 -ffast-math -O3 SFMT.c testrandom.cpp 
// -DMEXP=607 is slightly faster


#include "randomnumbergenerator.h"
// #include <emmintrin.h>


#include "sfmersenne.h"

SFMersenne sf;

class MWC2 {
public:

  MWC2 (unsigned int seed1, unsigned int seed2)
    : index (0)
  {
    for (int i = 0; i < NUM; i++) {
      z[i] = seed1++;
      w[i] = seed2++;
    }
    refill();
  }

  inline unsigned int next (void) {
    if (index == NUM) {
      refill();
      index = 0;
    }
    int ret = r[index];
    ++index;
    return ret;
  }

  void refill() {
    // These magic numbers are derived from a note by George Marsaglia.
    for (int i = 0; i < NUM; i++) {
      z[i]=36969*(z[i]&65535)+(z[i]>>16);
      w[i]=18000*(w[i]&65535)+(w[i]>>16);
      r[i] = (z[i] << 16) + w[i];
    }
  }
  
private:

  enum { NUM = 4 };

  unsigned int z[NUM] __attribute__((aligned(16)));
  unsigned int w[NUM] __attribute__((aligned(16)));
  unsigned int r[NUM] __attribute__((aligned(16)));
  unsigned int index;
  
};


//#include "SFMT.h"

class MT {
public:
  MT()
  {
    sf.init_gen_rand(RealRandomValue::value());
    index = 0;
    refill();
  }

  inline unsigned int next (void) {
    if (index == NUM) {
      refill();
      index = 0;
    }
    int ret = array32[index];
    ++index;
    return ret;
  }

private:

  SFMersenne sf;

  enum { NUM = 1024 };

  void refill() {
    sf.fill_array32 (array32, NUM);
  }

  uint32_t array32[NUM] __attribute__((aligned(16)));;
  int index;
};

// RandomNumberGenerator rng;
// MWC2 rng (RealRandomValue::value(), RealRandomValue::value());
MT rng;

main()
{
  printf ("%p\n", &rng);

  volatile int n;
  for (int i = 0; i < 100 * 100000; i++) {
    n = rng.next();
    n = rng.next();
    n = rng.next();
    n = rng.next();
    n = rng.next();
    n = rng.next();
    n = rng.next();
    n = rng.next();
    n = rng.next();
    n = rng.next();
  }
}
