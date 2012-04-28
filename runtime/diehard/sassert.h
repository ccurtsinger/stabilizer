// -*- C++ -*-

/**
 * @file   sassert.h
 * @brief  Implements compile-time assertion checking.
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 * @note   Copyright (C) 2005 by Emery Berger, University of Massachusetts Amherst.
 */


#ifndef _SASSERT_H_
#define _SASSERT_H_

/**
 * @class  sassert
 * @brief  Implements compile-time assertion checking.
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 *
 * @code
 *   sassert<(1+1 == 2)> CheckOnePlusOneIsTwo;
 * @endcode
 *
 */

  template <int assertion>
    class sassert;

  template<> class sassert<1> {
  public:
    enum { value = 1 };
  };

#endif
