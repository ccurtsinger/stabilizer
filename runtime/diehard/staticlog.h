// -*- C++ -*-

/**
 * @file   staticlog.h
 * @brief  Statically returns the log (base 2) of a value.
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 * @note   Copyright (C) 2005 by Emery Berger, University of Massachusetts Amherst.
 */

#ifndef _STATICLOG_H_
#define _STATICLOG_H_

#include "staticif.h"

template <int Number>
class StaticLog;

template <>
class StaticLog<1> {
public:
  enum { value = 0 };
};

template <>
class StaticLog<2> {
public:
  enum { value = 1 };
};

template <int Number>
class StaticLog {
public:
  enum { value = StaticIf<(Number > 1), StaticLog<Number/2>::value + 1, 0>::value };
};

#endif
