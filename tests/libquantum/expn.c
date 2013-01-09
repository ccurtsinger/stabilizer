/* expn.c: x^a mod n

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

#include <stdlib.h>
#include <stdio.h>
#if !defined(SPEC_CPU_WINDOWS_ICL)
#include <math.h>
#else
#include <mathimf.h>
#endif /* SPEC_CPU_WINDOWS_ICL */
#include "defs.h"
#include "gates.h"
#include "omuln.h"
#include "qureg.h"

void 
quantum_exp_mod_n(int N, int x, int width_input, int width, quantum_reg *reg)
{
	
	int i, j, f;
	
	

	quantum_sigma_x(2*width+2, reg);
	for (i=1; i<=width_input;i++){
		f=x%N;			//compute
		for (j=1;j<i;j++)
		  { 
		    f*=f;	//x^2^(i-1)
		    f= f%N;
		  }
		mul_mod_n(N,f,3*width+1+i, width, reg);
		}
	}
