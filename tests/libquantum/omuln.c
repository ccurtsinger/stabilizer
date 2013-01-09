/* omuln.c: Multiplication modulo an integer N

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

#include "defs.h"
#include "matrix.h"
#include "gates.h"
#include "oaddn.h"
#include "classic.h"

void emul(int a, int L, int width, quantum_reg *reg){

	int i;
	for(i=width-1;i>=0;i--) if ((a>>i) & 1) {
	quantum_toffoli(2*width+2,L,width+i,reg);
	}
}
	
void muln(int N, int a, int ctl, int width, quantum_reg *reg){//ctl tells, which bit is the external enable bit
	int i;
	int L = 2*width+1;

	quantum_toffoli(ctl,2*width+2,L,reg);

	emul(a%N, L, width, reg);

	quantum_toffoli(ctl,2*width+2,L,reg);

	for(i=1;i<width;i++){
		quantum_toffoli(ctl,2*width+2+i,L,reg);
		add_mod_n(N,((1<<i)*a)%N,width,reg);
		quantum_toffoli(ctl,2*width+2+i,L,reg);
		}


}

void muln_inv(int N, int a, int ctl, int width, quantum_reg *reg){//ctl tells, which bit is the external enable bit
	int i;
	int L = 2*width+1;

	a=quantum_inverse_mod(N,a);

	for(i=width-1;i>0;i--){
		quantum_toffoli(ctl,2*width+2+i,L,reg);
		add_mod_n(N,N-((1<<i)*a)%N,width,reg);
		quantum_toffoli(ctl,2*width+2+i,L,reg);
		}

		quantum_toffoli(ctl,2*width+2,L,reg);
		emul(a%N, L, width, reg);
		quantum_toffoli(ctl,2*width+2,L,reg);
	}


void mul_mod_n(int N, int a, int ctl, int width, quantum_reg *reg)
{
  muln(N,a,ctl,width,reg);

  quantum_swaptheleads_omuln_controlled(ctl, width, reg);

  muln_inv(N,a,ctl,width,reg);

}
