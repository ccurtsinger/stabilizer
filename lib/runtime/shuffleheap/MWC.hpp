// -*- C++ -*- 

#ifndef _MWC_H_
#define _MWC_H_

/**
 * @class MWC
 * @brief A super-fast multiply-with-carry pseudo-random number generator.
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 * @note   Copyright (C) 2005-2011 by Emery Berger, University of Massachusetts Amherst.
 */

class MWC {
public:

  MWC (unsigned int seed1, unsigned int seed2)
    : z (seed1), w (seed2)
  {}

  inline unsigned int next (void) {
    // These magic numbers are derived from a note by George Marsaglia.
    unsigned int znew = (z=36969*(z&65535)+(z>>16));
    unsigned int wnew = (w=18000*(w&65535)+(w>>16));
    unsigned int x = (znew << 16) + wnew;
    return x;
  }
  
private:

  unsigned int z;
  unsigned int w;
  
};

#endif
