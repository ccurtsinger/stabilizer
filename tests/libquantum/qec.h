/* gates.h: Declarations for qec.c

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

#ifndef __QEC_H

#define __QEC_H

#include "qureg.h"

extern void quantum_qec_set_status(int stype, int swidth);
extern void quantum_qec_get_status(int *ptype, int *pwidth);

extern void quantum_qec_encode(int type, int width, quantum_reg *reg);
extern void quantum_qec_decode(int type, int width, quantum_reg *reg);

extern void quantum_sigma_x_ft(int target, quantum_reg *reg);
extern void quantum_cnot_ft(int control, int target, quantum_reg *reg);
extern void quantum_toffoli_ft(int control1, int control2, int target, 
			       quantum_reg *reg);

#endif
