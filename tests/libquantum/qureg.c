/* qureg.c: Quantum register management

   Copyright 2003, 2004 Bjoern Butscher, Hendrik Weimer

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

#include <stdio.h>
#include <stdlib.h>
#if !defined(SPEC_CPU_WINDOWS_ICL)
#include <math.h>
#else
#include <mathimf.h>
#endif /* SPEC_CPU_WINDOWS_ICL */
#include "matrix.h"
#include "qureg.h"
#include "config.h"
#include "lq_complex.h"
#include "objcode.h"

/* Rahul: Must use SPEC's random number functions and not srandom and rand */
#if defined(SPEC_CPU)
#include "specrand.h"
#endif /* SPEC_CPU */

/* Convert a vector to a quantum register */

quantum_reg
quantum_matrix2qureg(quantum_matrix *m, int width)
{
  quantum_reg reg;
  int i, j, size=0;

  if(m->cols != 1)
    {
      printf("Error! Cannot convert a multi-column-matrix (%i)!\n", m->cols);
      exit(1);
    }

  reg.width = width;

  /* Determine the size of the quantum register */

  for(i=0; i<m->rows; i++)
    {
      if(m->t[i])
	size++;
    }

  /* Allocate the required memory */

  reg.size = size;
  reg.hashw = width + 2;

  reg.node = calloc(size, sizeof(quantum_reg_node));
  if(!reg.node)
    {
      printf("Not enough memory for %i-sized qubit!\n", size);
      exit(1);
    }
  quantum_memman(size * sizeof(quantum_reg_node));

  /* Allocate the hash table */

  reg.hash = calloc(1 << reg.hashw, sizeof(int));
  if(!reg.hash)
    {
      printf("Not enough memory for %i-sized hash!\n", 1 << reg.hashw);
      exit(1);
    }
  quantum_memman((1 << reg.hashw) * sizeof(int));

  /* Copy the nonzero amplitudes of the vector into the quantum
     register */

  for(i=0, j=0; i<m->rows; i++)
    {
      if(m->t[i])
	{
	  reg.node[j].state = i;
	  reg.node[j].amplitude = m->t[i];
	  j++;
	}
    }

  return reg;
}

/* Create a new quantum register from scratch */

quantum_reg
quantum_new_qureg(MAX_UNSIGNED initval, int width)
{
  quantum_reg reg;
  char *c;

  reg.width = width;
  reg.size = 1;
  reg.hashw = width + 2;

  /* Allocate memory for 1 base state */

  reg.node = calloc(1, sizeof(quantum_reg_node));
  if(!reg.node)
    {
      printf("Not enough memory for %i-sized qubit!\n", 1);
      exit(1);
    }
  quantum_memman(sizeof(quantum_reg_node));

  /* Allocate the hash table */

  reg.hash = calloc(1 << reg.hashw, sizeof(int));
  if(!reg.hash)
    {
      printf("Not enough memory for %i-sized hash!\n", 1 << reg.hashw);
      exit(1);
    }
  quantum_memman((1 << reg.hashw) * sizeof(int));

  /* Initialize the quantum register */
  
  reg.node[0].state = initval;
  reg.node[0].amplitude = 1;

  /* Initialize the PRNG */

  /*  srandom(time(0)); */

  c = getenv("QUOBFILE");

  if(c)
    {
      quantum_objcode_start();
      quantum_objcode_file(c);
      atexit((void *) &quantum_objcode_exit);
    }

  quantum_objcode_put(INIT, initval);

  return reg;
}

/* Convert a quantum register to a vector */

quantum_matrix
quantum_qureg2matrix(quantum_reg reg)
{
  quantum_matrix m;
  int i;

  m = quantum_new_matrix(1, 1 << reg.width);
  
  for(i=0; i<reg.size; i++)
    m.t[reg.node[i].state] = reg.node[i].amplitude;

  return m;
}

/* Destroys the entire hash table of a quantum register */

void
quantum_destroy_hash(quantum_reg *reg)
{
  free(reg->hash);
  quantum_memman(-(1 << reg->hashw) * sizeof(int));
  reg->hash = 0;
}

/* Delete a quantum register */

void
quantum_delete_qureg(quantum_reg *reg)
{
  quantum_destroy_hash(reg);
  free(reg->node);
  quantum_memman(-reg->size * sizeof(quantum_reg_node));
  reg->node = 0;
}

/* Delete a quantum register but leave the hash table alive */

void
quantum_delete_qureg_hashpreserve(quantum_reg *reg)
{
  free(reg->node);
  quantum_memman(-reg->size * sizeof(quantum_reg_node));
  reg->node = 0;
}

/* Print the contents of a quantum register to stdout */

void
quantum_print_qureg(quantum_reg reg)
{
  int i,j;
  
  for(i=0; i<reg.size; i++)
    {
      printf("% f %+fi|%lli> (%e) (|", quantum_real(reg.node[i].amplitude),
	     quantum_imag(reg.node[i].amplitude), reg.node[i].state, 
	     quantum_prob_inline(reg.node[i].amplitude));
      for(j=reg.width-1;j>=0;j--)
	{
	  if(j % 4 == 3)
	    printf(" ");
	  printf("%i", ((((MAX_UNSIGNED) 1 << j) & reg.node[i].state) > 0));
	}

      printf(">)\n");
    }

  printf("\n");
}

/* Print the output of the modular exponentation algorithm */

void
quantum_print_expn(quantum_reg reg)
{
  int i;
  
  for(i=0; i<reg.size; i++)
    {
      printf("%i: %lli\n", i, reg.node[i].state - i * (1 << (reg.width / 2)));
    }
}

/* Add additional space to a qureg. It is initialized to zero and can
   be used as scratch space. Note that the space gets added at the LSB */

void
quantum_addscratch(int bits, quantum_reg *reg)
{
  int i, oldwidth;
  MAX_UNSIGNED l;
  
  oldwidth = reg->width;

  reg->width += bits;

  for(i=0; i<reg->size; i++)
    {
      l = reg->node[i].state << bits;
      reg->node[i].state = l;
    }
}

/* Print the hash table to stdout and test if the hash table is
   corrupted */

void
quantum_print_hash(quantum_reg reg)
{
  int i;

  for(i=0; i < (1 << reg.hashw); i++)
    {
      if(i)
	printf("%i: %i %llu\n", i, reg.hash[i]-1, 
	       reg.node[reg.hash[i]-1].state);
    }

}

/* Compute the Kronecker product of two quantum registers */

quantum_reg
quantum_kronecker(quantum_reg *reg1, quantum_reg *reg2)
{
  int i,j;
  quantum_reg reg;
  
  reg.width = reg1->width+reg2->width;
  reg.size = reg1->size*reg2->size;
  reg.hashw = reg1->size*reg2->size + 2;


  /* allocate memory for the new basis states */
  
  reg.node = calloc(reg.size, sizeof(quantum_reg_node));
  if(!reg.node) 
    {
      printf("Not enough memory for %i-sized qubit!\n", reg.size);
      exit(1);
    }
  quantum_memman((reg.size)*sizeof(quantum_reg_node));


  /* Allocate the hash table */

  reg.hash = calloc(1 << reg.hashw, sizeof(int));
  if(!reg.hash)
    {
      printf("Not enough memory for %i-sized hash!\n", 1 << reg.hashw);
      exit(1);
    }
  quantum_memman((1 << reg.hashw) * sizeof(int));

  for(i=0; i<reg1->size; i++)
    for(j=0; j<reg2->size; j++)
    {
      /* printf("processing |%lli> x |%lli>\n", reg1->node[i].state, 
	     reg2->node[j].state);
         printf("%lli\n", (reg1->node[i].state) << reg2->width); */

      reg.node[i*reg2->size+j].state = 	((reg1->node[i].state) << reg2->width)
	| reg2->node[j].state;
      reg.node[i*reg2->size+j].amplitude = 
	reg1->node[i].amplitude * reg2->node[j].amplitude;
    }

  return reg;
}

/* Reduce the state vector after measurement or partial trace */

quantum_reg
quantum_state_collapse(int pos, int value, quantum_reg reg)
{
  int i, j, k;
  int size=0;
  double d=0;
  MAX_UNSIGNED lpat=0, rpat=0, pos2;
  quantum_reg out;

  pos2 = (MAX_UNSIGNED) 1 << pos;

  /* Eradicate all amplitudes of base states which have been ruled out
     by the measurement and get the norm of the new register */
  
  for(i=0;i<reg.size;i++)
    {
      if(((reg.node[i].state & pos2) && value) 
	 || (!(reg.node[i].state & pos2) && !value))
	{
	  d += quantum_prob_inline(reg.node[i].amplitude);
	  size++;
	}
    }

  /* Build the new quantum register */

  out.width = reg.width-1;
  out.size = size;
  out.node = calloc(size, sizeof(quantum_reg_node));
  if(!out.node)
    {
      printf("Not enough memory for %i-sized quantum register!\n", size);
      exit(1);
    }
  quantum_memman(size * sizeof(quantum_reg_node));
  out.hashw = reg.hashw;
  out.hash = reg.hash;

  /* Determine the numbers of the new base states and norm the quantum
     register */
  
  for(i=0, j=0; i<reg.size; i++)
    {
      if(((reg.node[i].state & pos2) && value) 
	 || (!(reg.node[i].state & pos2) && !value))
	{
	  for(k=0, rpat=0; k<pos; k++)
	  rpat += (MAX_UNSIGNED) 1 << k;

	  rpat &= reg.node[i].state;

	  for(k=sizeof(MAX_UNSIGNED)*8-1, lpat=0; k>pos; k--)
	    lpat += (MAX_UNSIGNED) 1 << k;

	  lpat &= reg.node[i].state;
  
	  out.node[j].state = (lpat >> 1) | rpat;
	  out.node[j].amplitude = reg.node[i].amplitude * 1 / (float) sqrt(d);
	
	  j++;
	}
    }

  return out;

}

/* Compute the dot product of two quantum registers */

COMPLEX_FLOAT
quantum_dot_product(quantum_reg *reg1, quantum_reg *reg2)
{
  int i, j;
  COMPLEX_FLOAT f = 0;

  for(i=0; i<(1 << reg2->hashw); i++)
    reg2->hash[i] = 0;
      
  for(i=0; i<reg2->size; i++)
    quantum_add_hash(reg2->node[i].state, i, reg2);

  for(i=0; i<reg1->size; i++)
    {
      j = quantum_get_state(reg1->node[i].state, *reg2);

      if(j > -1) /* state exists in reg2 */
	f += quantum_conj(reg1->node[i].amplitude) * reg2->node[j].amplitude;
    }

  return f;

}
