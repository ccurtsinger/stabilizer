/* complex.h: Declarations for complex.c

   Copyright 2003 Bjoern Butscher, Hendrik Weimer

   This file is part of libquantum

   libquantum is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published
   by the Free Software Foundation; either version 2 of the License,
   or (at your option) any later version.

   libquantum is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with libquantum; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
   USA

*/

#ifndef __COMPLEX_H

#define __COMPLEX_H

#include "config.h"

extern COMPLEX_FLOAT quantum_conj(COMPLEX_FLOAT a);

extern float quantum_prob (COMPLEX_FLOAT a);
extern COMPLEX_FLOAT quantum_cexp(float phi);

/* Return the real part of a complex number */

static inline float
quantum_real(COMPLEX_FLOAT a)
{
  float *p = (float *) &a;
  return p[0];
}

/* Return the imaginary part of a complex number */

static inline float
quantum_imag(COMPLEX_FLOAT a)
{
  float *p = (float *) &a;
  return p[1];
}

/* Calculate the square of a complex number (i.e. the probability) */

static inline float 
quantum_prob_inline(COMPLEX_FLOAT a)
{
  float r, i;

  r = quantum_real(a);
  i = quantum_imag(a);

  return r * r + i * i;
}

#endif
