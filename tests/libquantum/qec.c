/* qec.c: Quantum Error Correction

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

#include "qureg.h"
#include "gates.h"
#include "config.h"
#include "decoherence.h"
#include "measure.h"

/* Type of the QEC. Currently implemented versions are:

   0: no QEC (default)
   1: Steane's 3-bit code */

int type = 0;

/* How many qubits are protected */

int width = 0;


/* Change the status of the QEC. */

void
quantum_qec_set_status(int stype, int swidth)
{
  type = stype;
  width = swidth;
}

/* Get the current QEC status */
 
void
quantum_qec_get_status(int *ptype, int *pwidth)
{
  if(ptype)
    *ptype = type;
  if(pwidth)
    *pwidth = width;
} 

/* Encode a quantum register. All qubits up to SWIDTH are protected,
   the rest is expanded with a repition code. */

void
quantum_qec_encode(int type, int width, quantum_reg *reg)
{
  int i;
  float lambda;

  lambda = quantum_get_decoherence();

  quantum_set_decoherence(0);

  for(i=0;i<reg->width;i++)
    {
      if(i==reg->width-1)
	quantum_set_decoherence(lambda);

      if(i<width)
	{
	  quantum_hadamard(reg->width+i, reg);
	  quantum_hadamard(2*reg->width+i, reg);

	  quantum_cnot(reg->width+i, i, reg);
	  quantum_cnot(2*reg->width+i, i, reg);
	}
      else
	{
	  quantum_cnot(i, reg->width+i, reg);
	  quantum_cnot(i, 2*reg->width+i, reg);
	}
    }

  quantum_qec_set_status(1, reg->width);

  reg->width *= 3;
}

/* Decode a quantum register and perform Quantum Error Correction on
   it */

void
quantum_qec_decode(int type, int width, quantum_reg *reg)
{
  int i, a, b;
  int swidth;
  float lambda;

  lambda = quantum_get_decoherence();

  quantum_set_decoherence(0);

  swidth=reg->width/3;

  quantum_qec_set_status(0, 0);

  for(i=reg->width/3-1;i>=0;i--)
    {
      if(i==0)
	quantum_set_decoherence(lambda);

      if(i<width)
	{
	  quantum_cnot(2*swidth+i, i, reg);
	  quantum_cnot(swidth+i, i, reg);
	  
	  quantum_hadamard(2*swidth+i, reg);
	  quantum_hadamard(swidth+i, reg);
	}
      else
	{
	  quantum_cnot(i, 2*swidth+i, reg);
	  quantum_cnot(i, swidth+i, reg);
	}
    }

  for(i=1;i<=swidth;i++)
    {
      a = quantum_bmeasure(swidth, reg);
      b = quantum_bmeasure(2*swidth-i, reg);
      if(a == 1 && b == 1 && i-1 < width)
	quantum_sigma_z(i-1, reg); /* Z = HXH */
    }
}

/* Counter which can be used to apply QEC periodically */

int
quantum_qec_counter(int inc, int frequency, quantum_reg *reg)
{
  static int counter = 0;
  static int freq = (1<<30);

  if(inc > 0)
    counter += inc;
  else if(inc < 0)
    counter = 0;

  if(frequency > 0)
    freq = frequency;

  if(counter >= freq)
    {
      counter = 0;
      quantum_qec_decode(type, width, reg);
      quantum_qec_encode(type, width, reg);
    }
    
  return counter;
}

/* Fault-tolerant version of the NOT gate */

void
quantum_sigma_x_ft(int target, quantum_reg *reg)
{
  int tmp;
  float lambda;

  tmp = type;
  type = 0;

  lambda = quantum_get_decoherence();
  quantum_set_decoherence(0);

  /* These operations can be performed simultaneously */
  
  quantum_sigma_x(target, reg);
  quantum_sigma_x(target+width, reg);
  quantum_set_decoherence(lambda);
  quantum_sigma_x(target+2*width, reg);

  quantum_qec_counter(1, 0, reg);

  type = tmp;
}

/* Fault-tolerant version of the Controlled NOT gate */

void
quantum_cnot_ft(int control, int target, quantum_reg *reg)
{
  int tmp;
  float lambda;

  tmp = type;
  type = 0;

  /* These operations can be performed simultaneously */
  
  lambda = quantum_get_decoherence();
  quantum_set_decoherence(0);

  quantum_cnot(control, target, reg);
  quantum_cnot(control+width, target+width, reg);
  quantum_set_decoherence(lambda);
  quantum_cnot(control+2*width, target+2*width, reg);

  quantum_qec_counter(1, 0, reg);

  type = tmp;

}

/* Fault-tolerant version of the Toffoli gate */

void
quantum_toffoli_ft(int control1, int control2, int target, quantum_reg *reg)
{
  int i;
  int c1, c2;
  MAX_UNSIGNED mask;

  mask = ((MAX_UNSIGNED) 1 << target)
    + ((MAX_UNSIGNED) 1 << (target+width))
    + ((MAX_UNSIGNED) 1 << (target+2*width));

  for(i=0;i<reg->size;i++)
    {
      c1 = 0;
      c2 = 0;

      if(reg->node[i].state & ((MAX_UNSIGNED) 1 << control1))
	c1 = 1;
      if(reg->node[i].state 
	 & ((MAX_UNSIGNED) 1 << (control1+width)))
	{
	  c1 ^= 1;
	}
      if(reg->node[i].state 
	 & ((MAX_UNSIGNED) 1 << (control1+2*width)))
	{
	  c1 ^= 1;
	}

      if(reg->node[i].state & ((MAX_UNSIGNED) 1 << control2))
	c2 = 1;
      if(reg->node[i].state 
	 & ((MAX_UNSIGNED) 1 << (control2+width)))
	{
	  c2 ^= 1;
	}
      if(reg->node[i].state 
	 & ((MAX_UNSIGNED) 1 << (control2+2*width)))
	{
	  c2 ^= 1;
	}

      if(c1 == 1 && c2 == 1)
	reg->node[i].state = reg->node[i].state ^ mask;

    }

  quantum_decohere(reg);

  quantum_qec_counter(1, 0, reg);

}
