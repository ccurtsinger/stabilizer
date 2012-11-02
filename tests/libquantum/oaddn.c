/* oaddn.c: Addition modulo an integer N

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
#include <stdio.h>
#if !defined(SPEC_CPU_WINDOWS_ICL)
#include <math.h>
#else
#include <mathimf.h>
#endif /* SPEC_CPU_WINDOWS_ICL */
#include "matrix.h"
#include "measure.h"
#include "defs.h"
#include "gates.h"
#include "qureg.h"
#include "config.h"


/* if bit "compare" - the global enable bit - is set, test_sums
   checks, if the sum of the c-number and the q-number in register
   add_sum is greater than n and sets the next lower bit to "compare" */

void
test_sum(int compare, int width, quantum_reg *reg)
{
  int i;

  if (compare & ((MAX_UNSIGNED) 1 << (width - 1)))
    {
      quantum_cnot(2*width-1, width-1, reg);
      quantum_sigma_x(2*width-1, reg);
      quantum_cnot(2*width-1, 0, reg);
    }
  else
    {
      quantum_sigma_x(2*width-1, reg);
      quantum_cnot(2*width-1,width-1, reg);
    }
  for (i = (width-2);i>0;i--)
    {
      if (compare & (1<<i))
	{//is bit i set in compare?
	  quantum_toffoli(i+1,width+i,i, reg);
	  quantum_sigma_x(width+i, reg);
	  quantum_toffoli(i+1,width+i,0, reg);
	}
      else
	{
	  quantum_sigma_x(width+i, reg);
	  quantum_toffoli(i+1,width+i,i, reg);
	}
    }
  if (compare & 1) 
    {
      quantum_sigma_x(width, reg);
      quantum_toffoli(width,1,0, reg);
    }
  quantum_toffoli(2*width+1,0,2*width, reg);//set output to 1 if enabled and b < compare

  if (compare & 1) 
    {
      quantum_toffoli(width,1,0, reg);
      quantum_sigma_x(width, reg);
    }

  for (i = 1;i<=(width-2);i++)
    {
      if (compare & (1<<i))
	{//is bit i set in compare?
	  quantum_toffoli(i+1,width+i,0, reg);
	  quantum_sigma_x(width+i, reg);
	  quantum_toffoli(i+1,width+i,i, reg);
	}
      else
	{
	  quantum_toffoli(i+1,width+i,i, reg);
	  quantum_sigma_x(width+i, reg);
	}
    }
  if (compare & (1<<(width-1)))
    {
      quantum_cnot(2*width-1,0, reg);
      quantum_sigma_x(2*width-1, reg);
      quantum_cnot(2*width-1,width-1, reg);
    }
  else
    {
      quantum_cnot(2*width-1,width-1, reg);
      quantum_sigma_x(2*width-1, reg);
       }

  }


//This is a semi-quantum fulladder. It adds to b_in
//a c-number. Carry-in bit is c_in and carry_out is
//c_out. xlt-l and L are enablebits. See documentation
//for further information

void muxfa(int a, int  b_in, int c_in, int c_out, int xlt_l,int L, int total,quantum_reg *reg){//a,

  if(a==0){//00
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_cnot(b_in,c_in, reg);
  }

  if(a==3){//11
  quantum_toffoli(L,c_in,c_out, reg);
  quantum_cnot(L,c_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_cnot(b_in,c_in, reg);
  }

  if(a==1){//01
  quantum_toffoli(L,xlt_l,b_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_toffoli(L,xlt_l,b_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_toffoli(L,xlt_l,c_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_cnot(b_in,c_in, reg);
  }


  if(a==2){//10
  quantum_sigma_x(xlt_l, reg);
  quantum_toffoli(L,xlt_l,b_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_toffoli(L,xlt_l,b_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_toffoli(L,xlt_l,c_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_cnot(b_in,c_in, reg);
  quantum_sigma_x(xlt_l, reg);
  }
}


//This is just the inverse operation of the semi-quantum fulladder

void muxfa_inv(int a,int  b_in,int c_in,int c_out, int xlt_l,int L,int total,quantum_reg *reg){//a,

  if(a==0){//00
  quantum_cnot(b_in,c_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  }

  if(a==3){//11
  quantum_cnot(b_in,c_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_cnot(L,c_in, reg);
  quantum_toffoli(L,c_in,c_out, reg);
  }

  if(a==1){//01
  quantum_cnot(b_in,c_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_toffoli(L,xlt_l,c_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_toffoli(L,xlt_l,b_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_toffoli(L,xlt_l,b_in, reg);
  }


  if(a==2){//10
  quantum_sigma_x(xlt_l, reg);
  quantum_cnot(b_in,c_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_toffoli(L,xlt_l,c_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_toffoli(L,xlt_l,b_in, reg);
  quantum_toffoli(b_in,c_in,c_out, reg);
  quantum_toffoli(L,xlt_l,b_in, reg);
  quantum_sigma_x(xlt_l, reg);
  }
}

//This is a semi-quantum halfadder. It adds to b_in
//a c-number. Carry-in bit is c_in and carry_out is
//not necessary. xlt-l and L are enablebits. See
//documentation for further information

void muxha(int a,int  b_in,int c_in, int xlt_l, int L,int total,quantum_reg *reg){//a,

  if(a==0){//00
  quantum_cnot(b_in,c_in, reg);
  }

  if(a==3){//11
  quantum_cnot(L,c_in, reg);
  quantum_cnot(b_in,c_in, reg);
  }

  if(a==1){//01
  quantum_toffoli(L,xlt_l,c_in, reg);
  quantum_cnot(b_in,c_in, reg);
  }


  if(a==2){//10
  quantum_sigma_x(xlt_l, reg);
  quantum_toffoli(L,xlt_l,c_in, reg);
  quantum_cnot(b_in,c_in, reg);
  quantum_sigma_x(xlt_l, reg);
  }
}


//just the inverse of the semi quantum-halfadder

void muxha_inv(int a,int  b_in,int c_in, int xlt_l, int L, int total,quantum_reg *reg){//a,

  if(a==0){//00
  quantum_cnot(b_in,c_in, reg);
  }

  if(a==3){//11
  quantum_cnot(b_in,c_in, reg);
  quantum_cnot(L,c_in, reg);
  }

  if(a==1){//01
  quantum_cnot(b_in,c_in, reg);
  quantum_toffoli(L,xlt_l,c_in, reg);
  }


  if(a==2){//10
  quantum_sigma_x(xlt_l, reg);
  quantum_cnot(b_in,c_in, reg);
  quantum_toffoli(L,xlt_l,c_in, reg);
  quantum_sigma_x(xlt_l, reg);
  }
}

//

void madd(int a,int a_inv,int  width,quantum_reg *reg){
	int i,j;
	int total;
	total = num_regs*width+2;
	for (i = 0; i< width-1; i++){
		if((1<<i) & a) j= 1<<1;
	  	  else j=0;
		if((1<<i) & a_inv) j+=1;
		muxfa(j,width+i,i,i+1,2*width,2*width+1, total, reg);
		}
	j=0;
	if((1<<(width-1)) & a) j= 2;
	if((1<<(width-1)) & a_inv) j+=1;
	muxha(j,2*width-1,width-1,2*width,2*width+1, total, reg);
}

void madd_inv(int a,int a_inv,int  width,quantum_reg *reg){
	int i,j;
	int total;
	total = num_regs*width+2;
	j=0;

	if((1<<(width-1)) & a) j= 2;
	if((1<<(width-1)) & a_inv) j+=1;
	muxha_inv(j,width-1,2*width-1,2*width, 2*width+1, total, reg);

	for (i = width-2; i>=0; i--){
		if((1<<i) & a) j= 1<<1;
	  	  else j=0;
		if((1<<i) & a_inv) j+=1;
		muxfa_inv(j,i,width+i,width+1+i,2*width, 2*width+1, total, reg);
		}
}

void addn(int N,int a,int width, quantum_reg *reg){//add a to register reg (mod N)

	test_sum(N-a,width,reg); //xlt N-a
	madd((1<<(width))+a-N,a,width,reg);//madd 2^K+a-N

}

void addn_inv(int N,int a,int width, quantum_reg *reg){//inverse of add a to register reg (mod N)

  quantum_cnot(2*width+1,2*width,reg);//Attention! cnot gate instead of not, as in description
  madd_inv((1<<(width))-a,N-a,width,reg);//madd 2^K+(N-a)-N = 2^K-a

  quantum_swaptheleads(width,reg);

  test_sum(a,width,reg);
}

void add_mod_n(int N,int a,int width, quantum_reg *reg){//add a to register reg (mod N) and clear the scratch bits

	addn(N, a, width, reg);
	addn_inv(N, a, width, reg);
}

