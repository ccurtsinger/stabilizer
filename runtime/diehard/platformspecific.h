// -*- C++ -*-

/**
 * @file   platformspecific.h
 * @brief  Platform-specific compiler directives.
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 * @note   Copyright (C) 2005 by Emery Berger, University of Massachusetts Amherst.
 */


#ifndef _PLATFORMSPECIFIC_H_
#define _PLATFORMSPECIFIC_H_

#if defined(_WIN32)

// Turn inlining hints into requirements.
#pragma inline_depth(255)
#define inline __forceinline
#pragma warning(disable: 4530)
#pragma warning(disable:4273)
#define NO_INLINE __declspec(noinline)

#elif defined(__GNUC__)

#define NO_INLINE __attribute__ ((noinline))
//#define inline __attribute__((always_inline))

#else
#define NO_INLINE
#endif

#endif
