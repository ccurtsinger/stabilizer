// -*- C++ -*-

/**
 * @file   randomnumbergenerator.h
 * @brief  A generic interface to random number generators.
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 * @note   Copyright (C) 2005 by Emery Berger, University of Massachusetts Amherst.
 */

#ifndef _RANDOMNUMBERGENERATOR_H_
#define _RANDOMNUMBERGENERATOR_H_

#define USE_MERSENNE 0

#if USE_MERSENNE
#include "mersennetwister.h"
#else
#include "mwc.h"
#endif

#include "realrandomvalue.h"

class RandomNumberGenerator {
public:

  RandomNumberGenerator() // (unsigned int seed1, unsigned int seed2) 
    : mt (RealRandomValue::value(), RealRandomValue::value()) {
    // : mt (362436069, 521288629)  {
  }

  inline unsigned int next (void) {
    return mt.next();
  }

private:

#if USE_MERSENNE
  MersenneTwister mt;
#else
   MWC mt;
#endif
};

#endif
