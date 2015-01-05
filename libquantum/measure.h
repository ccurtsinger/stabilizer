/* measure.h: Declarations for measure.c

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

#ifndef __MEASURE_H

#define __MEASURE_H

#include "matrix.h"
#include "qureg.h"
#include "config.h"

extern double quantum_frand();

extern MAX_UNSIGNED quantum_measure(quantum_reg reg);
extern int quantum_bmeasure(int pos, quantum_reg *reg);
extern int quantum_bmeasure_bitpreserve(int pos, quantum_reg *reg);

#endif
