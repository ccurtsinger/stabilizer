// -*- C++ -*-

#ifndef _MERSENNE_H_
#define _MERSENNE_H_

class Mersenne {
public:

  Mersenne (unsigned long seed1, unsigned long seed2)
  {
    seed (seed1);
  }

  inline unsigned long next (void)
  {
    if (p == N) gen_state(); // new state vector needed
    // gen_state() is split off to be non-inline, because it is only called once
    // in every 624 calls and otherwise irand() would become too big to get inlined
    register unsigned long x = state(p++);
    x ^= (x >> 11);
    x ^= (x << 7) & 0x9D2C5680UL;
    x ^= (x << 15) & 0xEFC60000UL;
    return x ^ (x >> 18);
  }

private:

  enum { N = 624, M = 397}; // compile time constants
  int p; // position in state array

  inline static unsigned long twiddle(unsigned long u, unsigned long v) {
    return (((u & 0x80000000UL) | (v & 0x7FFFFFFFUL)) >> 1)
      ^ ((v & 1UL) ? 0x9908B0DFUL : 0x0UL);
  }

  inline unsigned long& state (const int index) {
    return _state[index];
  }

  unsigned long _state[N]; // state vector array
 
private:

  NO_INLINE void gen_state (void)
  {
    for (int i = 0; i < (N - M); ++i)
      state(i) = state(i + M) ^ twiddle(state(i), state(i + 1));
    for (int i = N - M; i < (N - 1); ++i)
      state(i) = state(i + M - N) ^ twiddle(state(i), state(i + 1));
    state(N - 1) = state(M - 1) ^ twiddle(state(N - 1), state(0));
    p = 0; // reset position
  }

  void seed (unsigned long s) {
    state(0) = s & 0xFFFFFFFFUL; // for > 32 bit machines
    for (int i = 1; i < N; ++i) {
      state(i) = 1812433253UL * (state(i - 1) ^ (state(i - 1) >> 30)) + i;
      // see Knuth TAOCP Vol2. 3rd Ed. P.106 for multiplier
      // in the previous versions, MSBs of the seed affect only MSBs of the array state
      // 2002/01/09 modified by Makoto Matsumoto
      state(i) &= 0xFFFFFFFFUL; // for > 32 bit machines
    }
    p = N; // force gen_state() to be called for next random number
  }
 
};

#endif
