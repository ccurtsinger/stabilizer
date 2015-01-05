/* qureg.h: Declarations for qureg.c and inline hashing functions

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

#ifndef __QUREG_H

#define __QUREG_H

#include <sys/types.h>

#include "config.h"
#include "matrix.h"

/* Representation of a base state of a quantum register: alpha_j |j> */

struct quantum_reg_node_struct
{
  COMPLEX_FLOAT amplitude; /* alpha_j */
  MAX_UNSIGNED state;      /* j */
};

typedef struct quantum_reg_node_struct quantum_reg_node;

/* The quantum register */

struct quantum_reg_struct
{
  int width;    /* number of qubits in the qureg */
  int size;     /* number of non-zero vectors */
  int hashw;    /* width of the hash array */
  quantum_reg_node *node;
  int *hash;
};

typedef struct quantum_reg_struct quantum_reg;

extern quantum_reg quantum_matrix2qureg(quantum_matrix *m, int width);
extern quantum_reg quantum_new_qureg(MAX_UNSIGNED initval, int width);
extern quantum_matrix quantum_qureg2matrix(quantum_reg reg);
extern void quantum_destroy_hash(quantum_reg *reg);
extern void quantum_delete_qureg(quantum_reg *reg);
extern void quantum_delete_qureg_hashpreserve(quantum_reg *reg);

extern void quantum_print_qureg(quantum_reg reg);
extern void quantum_print_expn(quantum_reg reg);

extern void quantum_addscratch(int bits, quantum_reg *reg);

extern void quantum_print_hash(quantum_reg reg);

extern quantum_reg quantum_kronecker(quantum_reg *reg1, quantum_reg *reg2);

extern quantum_reg quantum_state_collapse(int bit, int value, 
					  quantum_reg reg);

extern COMPLEX_FLOAT quantum_dot_product(quantum_reg *reg1, quantum_reg *reg2);

/* Our 64-bit multiplicative hash function */

static inline unsigned int
quantum_hash64(MAX_UNSIGNED key, int width)
{
  unsigned int k32;

  k32 = (key & 0xFFFFFFFF) ^ (key >> 32);

  k32 *= 0x9e370001UL;
  k32 = k32 >> (32-width);

  return k32;
}

/* Get the position of a given base state via the hash table */

static inline int
quantum_get_state(MAX_UNSIGNED a, quantum_reg reg)
{
  int i;

  i = quantum_hash64(a, reg.hashw);

  while(reg.hash[i])
    {
      if(reg.node[reg.hash[i]-1].state == a)
	return reg.hash[i]-1;
      i++;
      if(i == (1 << reg.hashw))
	i = 0;
    }
  
  return -1;
    
}

/* Add an element to the hash table */

static inline void
quantum_add_hash(MAX_UNSIGNED a, int pos, quantum_reg *reg)
{
  int i;

  i = quantum_hash64(a, reg->hashw);

  while(reg->hash[i])
    {
      i++;
      if(i == (1 << reg->hashw))
	i = 0;
    }

  reg->hash[i] = pos+1;

}

#endif
