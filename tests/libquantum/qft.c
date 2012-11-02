/* qft.c: Quantum Fourier Transform
   
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

#include "gates.h"
#include "qureg.h"

/* Perform a QFT on a quantum register. This is done by application of
   conditional phase shifts and hadamard gates. At the end, the
   position of the bits is reversed. */

void quantum_qft(int width, quantum_reg *reg)
{
  int i, j;

  for(i=width-1; i>=0; i--)
    {
      for(j=width-1; j>i; j--)
	quantum_cond_phase(j, i, reg);

      quantum_hadamard(i, reg);
    }

}


void quantum_qft_inv(int width, quantum_reg *reg)
{
  int i, j;

  for(i=0; i<width; i++)
    {
      quantum_hadamard(i, reg);

      for(j=i+1; j<width; j++)
	quantum_cond_phase_inv(j, i, reg);

    }

}
