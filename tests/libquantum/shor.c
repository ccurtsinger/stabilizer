 /* shor.c: Implementation of Shor's factoring algorithm

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
#include <time.h>

#if !defined(SPEC_CPU)
#include <quantum.h>
#else
#include "quantum.h"
#endif /* SPEC_CPU */

/* Rahul: Must use SPEC's random number functions and not srandom and rand */
#if defined(SPEC_CPU)
#include "specrand.h"
#endif /* SPEC_CPU */

int main(int argc, char **argv) {

  quantum_reg qr;
  int i;
  int width, swidth;
  int x = 0;
  int N;
  int c,q,a,b, factor;

#if defined(SPEC_CPU)
	spec_srand(26);			
#else
	srandom(time(0));
#endif /* SPEC_CPU */

  if(argc == 1)
    {
      printf("Usage: shor [number]\n\n");
      return 3;
    }

  N=atoi(argv[1]);

  if(N<15)
    {
      printf("Invalid number\n\n");
      return 3;
    }

  width=quantum_getwidth(N*N);
  swidth=quantum_getwidth(N);

  printf("N = %i, %i qubits required\n", N, width+3*swidth+2);

  if(argc >= 3)
    {
      x = atoi(argv[2]);
    }
  while((quantum_gcd(N, x) > 1) || (x < 2))
    {
 #if defined(SPEC_CPU)
	x = (long)(spec_rand() * 2147483647L) % N;        
 #else
	x = random() % N;
 #endif /* SPEC_CPU */
    } 

  printf("Random seed: %i\n", x);

  qr=quantum_new_qureg(0, width);

  for(i=0;i<width;i++)
    quantum_hadamard(i, &qr);

  quantum_addscratch(3*swidth+2, &qr);

  quantum_exp_mod_n(N, x, width, swidth, &qr);

  for(i=0;i<3*swidth+2;i++)
    {
      quantum_bmeasure(0, &qr);
    }

  quantum_qft(width, &qr); 
  
  for(i=0; i<width/2; i++)
    {
      quantum_cnot(i, width-i-1, &qr);
      quantum_cnot(width-i-1, i, &qr);
      quantum_cnot(i, width-i-1, &qr);
    }
  
  c=quantum_measure(qr);

  if(c==-1)
    {
      printf("Impossible Measurement!\n");
      exit(1);
    }

  if(c==0)
    {
      printf("Measured zero, try again.\n");
      exit(2);
    }

  q = 1<<(width);

  printf("Measured %i (%f), ", c, (float)c/q);

  quantum_frac_approx(&c, &q, width);

  printf("fractional approximation is %i/%i.\n", c, q);

  if((q % 2 == 1) && (2*q<(1<<width)))
    {
      printf("Odd denominator, trying to expand by 2.\n");
      q *= 2;
    }
    
  if(q % 2 == 1)
    {
      printf("Odd period, try again.\n");
      exit(2);
    }

  printf("Possible period is %i.\n", q);
  
  a = quantum_ipow(x, q/2) + 1 % N;
  b = quantum_ipow(x, q/2) - 1 % N;
  
  a = quantum_gcd(N, a);
  b = quantum_gcd(N, b);
  
  if(a>b)
    factor=a;
  else
    factor=b;

  if((factor < N) && (factor > 1))
    {
      printf("%i = %i * %i\n", N, factor, N/factor);
    }
  else
    {
      printf("Unable to determine factors, try again.\n");
#if defined(SPEC_CPU)
	exit(0);
#else
	exit(2);
#endif /* SPEC_CPU */
    }
    
  quantum_delete_qureg(&qr);

  /*  printf("Memory leak: %i bytes\n", (int) quantum_memman(0)); */

  return 0;
}
