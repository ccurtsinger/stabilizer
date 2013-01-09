/* matrix.h: Declarations for matrix.c

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

#ifndef __MATRIX_H

#define __MATRIX_H

#include "config.h"

/* A ROWS x COLS matrix with complex elements */

struct quantum_matrix_struct {
  int rows;
  int cols;
  COMPLEX_FLOAT *t;
};

typedef struct quantum_matrix_struct quantum_matrix;

#define M(m,x,y) m.t[x+y*m.cols]

extern unsigned long quantum_memman(long change);

extern quantum_matrix quantum_new_matrix(int cols, int rows);
extern void quantum_delete_matrix(quantum_matrix *m);
extern void quantum_print_matrix(quantum_matrix m);

#endif
