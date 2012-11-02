/* classic.h: Declarations for classic.c

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

#ifndef __CLASSIC_H

#define __CLASSIC_H

extern int quantum_ipow(int a, int b);
extern int quantum_gcd(int u, int v);

extern void quantum_frac_approx(int *a, int *b, int width);
extern int quantum_getwidth(int n);

extern int quantum_inverse_mod(int n, int c);

#endif
