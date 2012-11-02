/* gates.h: Declarations for gates.c

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

#ifndef __GATES_H

#define __GATES_H

#include "matrix.h"
#include "qureg.h"

extern void quantum_cnot(int control, int target, quantum_reg *reg);
extern void quantum_toffoli(int control1, int control2, int target, 
			    quantum_reg *reg);
extern void quantum_unbounded_toffoli(int controlling, quantum_reg *reg, ...);

extern void quantum_sigma_x(int target, quantum_reg *reg);
extern void quantum_sigma_y(int target, quantum_reg *reg);
extern void quantum_sigma_z(int target, quantum_reg *reg);

extern void quantum_swaptheleads(int width, quantum_reg *reg);
extern void quantum_swaptheleads_omuln_controlled(int control, int width,
					  quantum_reg *);

extern void quantum_gate1(int target, quantum_matrix m, quantum_reg *reg);

extern void quantum_r_x(int target, float gamma, quantum_reg *reg);
extern void quantum_r_y(int target, float gamma, quantum_reg *reg);
extern void quantum_r_z(int target, float gamma, quantum_reg *reg);

extern void quantum_hadamard(int target, quantum_reg *reg);
extern void quantum_walsh(int width, quantum_reg *reg);

extern void quantum_phase_scale(int target, float gamma, quantum_reg *reg);
extern void quantum_phase_kick(int target, float gamma, quantum_reg *reg);

extern void quantum_cond_phase(int control, int target, quantum_reg *reg);
extern void quantum_cond_phase_inv(int control, int target, quantum_reg *reg);

extern void quantum_cond_phase_kick(int control, int target, float gamma, 
				    quantum_reg *reg);

extern int quantum_gate_counter(int inc);

#endif
