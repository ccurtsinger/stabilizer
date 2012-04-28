// -*- C++ -*-

/**
 * @file   staticif.h
 * @brief  Statically returns a value based on a conditional.
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 * @note   Copyright (C) 2005 by Emery Berger, University of Massachusetts Amherst.
 */

#ifndef _STATICIF_H_
#define _STATICIF_H_

template <bool b, int a, int c>
class StaticIf;

template <int a, int b>
class StaticIf<true, a, b> {
 public:
  enum { value = a };
};

template <int a, int b>
class StaticIf<false, a, b> {
 public:
  enum { value = b };
};


#endif
