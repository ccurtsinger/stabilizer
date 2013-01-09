/* quantum.h: Header file for libquantum

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

#ifndef __QUANTUM_H

#define __QUANTUM_H

#if defined(SPEC_CPU)
#include "config.h"
#endif /* SPEC_CPU */

/* A ROWS x COLS matrix with complex elements */

struct quantum_matrix_struct {
  int rows;
  int cols;
  COMPLEX_FLOAT *t;
};

typedef struct quantum_matrix_struct quantum_matrix;

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

extern quantum_reg quantum_new_qureg(MAX_UNSIGNED initval, int width);
extern void quantum_delete_qureg(quantum_reg *reg);
extern void quantum_print_qureg(quantum_reg reg);
extern void quantum_addscratch(int bits, quantum_reg *reg);

extern void quantum_cnot(int control, int target, quantum_reg *reg);
extern void quantum_toffoli(int control1, int control2, int target, 
			    quantum_reg *reg);
extern void quantum_unbounded_toffoli(int controlling, quantum_reg *reg, ...);
extern void quantum_sigma_x(int target, quantum_reg *reg);
extern void quantum_sigma_y(int target, quantum_reg *reg);
extern void quantum_sigma_z(int target, quantum_reg *reg);
extern void quantum_gate1(int target, quantum_matrix m, quantum_reg *reg);
extern void quantum_r_x(int target, float gamma, quantum_reg *reg);
extern void quantum_r_y(int target, float gamma, quantum_reg *reg);
extern void quantum_r_z(int target, float gamma, quantum_reg *reg);
extern void quantum_phase_scale(int target, float gamma, quantum_reg *reg);
extern void quantum_phase_kick(int target, float gamma, quantum_reg *reg);
extern void quantum_hadamard(int target, quantum_reg *reg);
extern void quantum_walsh(int width, quantum_reg *reg);
extern void quantum_cond_phase(int control, int target, quantum_reg *reg);
extern void quantum_cond_phase_inv(int control, int target, quantum_reg *reg);
extern void quantum_cond_phase_kick(int control, int target, float gamma, 
				    quantum_reg *reg);
extern int quantum_gate_counter(int inc);

extern void quantum_qft(int width, quantum_reg *reg);
extern void quantum_qft_inv(int width, quantum_reg *reg);

extern void quantum_exp_mod_n(int N, int x, int width_input, int width, 
			      quantum_reg *reg);

extern MAX_UNSIGNED quantum_measure(quantum_reg reg);
extern int quantum_bmeasure(int pos, quantum_reg *reg);
extern int quantum_bmeasure_bitpreserve(int pos, quantum_reg *reg);

extern quantum_matrix quantum_new_matrix(int cols, int rows);
extern void quantum_delete_matrix(quantum_matrix *m);

extern int quantum_ipow(int a, int b);
extern int quantum_gcd(int u, int v);
extern void quantum_cancel(int *a, int *b);
extern void quantum_frac_approx(int *a, int *b, int width);
extern int quantum_getwidth(int n);

extern float quantum_prob(COMPLEX_FLOAT a);

extern float quantum_get_decoherence();
extern void quantum_set_decoherence(float lambda);
extern void quantum_decohere(quantum_reg *reg);

extern quantum_reg quantum_matrix2qureg(quantum_matrix *m, int width);
extern quantum_matrix quantum_qureg2matrix(quantum_reg reg);

extern void quantum_qec_encode(int type, int width, quantum_reg *reg);
extern void quantum_qec_decode(int type, int width, quantum_reg *reg);

extern const char * quantum_get_version();

extern void quantum_objcode_start();
extern void quantum_objcode_stop();
extern int quantum_objcode_write(char *file);
extern void quantum_objcode_run(char *file, quantum_reg *reg);

#endif
