/* objcode.c: Quantum object code functions

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

#include <stdarg.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>

#include "objcode.h"
#include "config.h"
#include "matrix.h"
#include "qureg.h"
#include "gates.h"
#include "measure.h"

/* status of the objcode functionality (0 = disabled) */

int opstatus = 0;

/* Generated OBJCODE data */

unsigned char *objcode = 0;

/* Current POSITION of the last instruction in the OBJCODE array */

unsigned long position = 0;

/* Number of ALLOCATED pages */

unsigned long allocated = 0;

/* file to write the object code to, if not given */

char *globalfile;

/* Convert a big integer to a byte array */

void
quantum_mu2char(MAX_UNSIGNED mu, unsigned char *buf)
{
  int i, size;
  
  size = sizeof(MAX_UNSIGNED);

  for(i=0; i<size; i++)
    {
      buf[i] = mu / ((MAX_UNSIGNED) 1 << ((size - i - 1) * 8));
      mu %= (MAX_UNSIGNED) 1 << ((size - i - 1) * 8);
    }
}

/* Convert an integer to a byte array */

void
quantum_int2char(int j, unsigned char *buf)
{
  int i, size;
  
  size = sizeof(int);

  for(i=0; i<size; i++)
    {
      buf[i] = j / (1 << ((size - i - 1) * 8));
      j %= (1 << ((size - i - 1) * 8));
    }
}

/* Copy the binary representation of a double to a byte array */

void
quantum_double2char(double d, unsigned char *buf)
{
  int i;
  unsigned char *p = (unsigned char *) &d;

  for(i=0; i<sizeof(double); i++)
    buf[i] = p[i];
}

MAX_UNSIGNED quantum_char2mu(unsigned char *buf)
{
  int i, size;
  MAX_UNSIGNED mu = 0;

  size = sizeof(MAX_UNSIGNED);

  for(i=size-1; i>=0 ; i--)
    mu += buf[i] * ((MAX_UNSIGNED) 1 << (8 * (size - i - 1)));

  return mu;
}

int quantum_char2int(unsigned char *buf)
{
  int i, size;
  int j = 0;

  size = sizeof(int);

  for(i=size-1; i>=0 ; i--)
    j += buf[i] * (1 << (8 * (size - i - 1)));

  return j;
}

double quantum_char2double(unsigned char *buf)
{
  double *d = (double *) buf;

  return *d;
}


/* Start object code recording */

void
quantum_objcode_start()
{
  opstatus = 1;
  allocated = 1;
  objcode = malloc(OBJCODE_PAGE * sizeof(char));
  if(!objcode)
    {
      printf("Error allocating memory for objcode data!\n");
      exit(1);
    }
  quantum_memman(OBJCODE_PAGE * sizeof(char));
}

/* Stop object code recording */

void
quantum_objcode_stop()
{
  opstatus = 0;
  free(objcode);
  objcode = 0;
  quantum_memman(- allocated * OBJCODE_PAGE * sizeof(char));
  allocated = 0;
}

/* Store an operation with its arguments in the object code data */

int
quantum_objcode_put(unsigned char operation, ...)
{
  int i, size;
  va_list args;
  unsigned char buf[80];
  double d;
  MAX_UNSIGNED mu;

  if(!opstatus)
    return 0;

  va_start(args, operation);
  
  buf[0] = operation;
  
  switch(operation)
    {
    case INIT:
      mu = va_arg(args, MAX_UNSIGNED);
      quantum_mu2char(mu, &buf[1]);
      size = sizeof(MAX_UNSIGNED) + 1;
      break;
    case CNOT:
    case COND_PHASE:
      i = va_arg(args, int);
      quantum_int2char(i, &buf[1]);
      i = va_arg(args, int);
      quantum_int2char(i, &buf[sizeof(int)+1]);
      size = 2 * sizeof(int) + 1;
      break;
    case TOFFOLI:
      i = va_arg(args, int);
      quantum_int2char(i, &buf[1]);
      i = va_arg(args, int);
      quantum_int2char(i, &buf[sizeof(int)+1]);
      i = va_arg(args, int);
      quantum_int2char(i, &buf[2*sizeof(int)+1]);
      size = 3 * sizeof(int) + 1;
      break;
    case SIGMA_X:
    case SIGMA_Y:
    case SIGMA_Z:
    case HADAMARD:
    case BMEASURE:
    case BMEASURE_P:
    case SWAPLEADS:
      i = va_arg(args, int);
      quantum_int2char(i, &buf[1]);
      size = sizeof(int) + 1;
      break;
    case ROT_X:
    case ROT_Y:
    case ROT_Z:
    case PHASE_KICK:
    case PHASE_SCALE:
      i = va_arg(args, int);
      d = va_arg(args, double);
      quantum_int2char(i, &buf[1]);
      quantum_double2char(d, &buf[sizeof(int)+1]);
      size = sizeof(int) + sizeof(double) + 1;
      break;
    case CPHASE_KICK:
      i = va_arg(args, int);
      quantum_int2char(i, &buf[1]);
      i = va_arg(args, int);
      quantum_int2char(i, &buf[sizeof(int)+1]);
      d = va_arg(args, double);
      quantum_double2char(d, &buf[2*sizeof(int)+1]);
      size = 2 * sizeof(int) + sizeof(double) + 1;
      break;
    case MEASURE:
    case NOP:
      size = 1;
      break;
    default:
      printf("Unknown opcode 0x(%X)!\n", operation);
      exit(1);
    }
  
  if((position+size) / OBJCODE_PAGE > position / OBJCODE_PAGE)
    {
      allocated++;
      objcode = realloc(objcode, allocated * OBJCODE_PAGE);
      if(!objcode)
	{
	  printf("Error reallocating memory for objcode data!\n");
	  exit(1);
	}
      quantum_memman(OBJCODE_PAGE * sizeof(char));
    }

  for(i=0; i<size; i++)
    {
      objcode[position] = buf[i];
      position++;
    }

  return 1;
}

/* Save the recorded object code data to a file */

int
quantum_objcode_write(char *file)
{
  FILE *fhd;

  if(!opstatus)
    {
      fprintf(stderr, "Object code generation not active! Forgot to call quantum_objcode_start?\n");
      return 1;
    }

  if(!file)
    file = globalfile;
  
  fhd = fopen(file, "w");

  if (fhd == 0)
    return -1;

  fwrite(objcode, position, 1, fhd);

  fclose(fhd);

  return 0;
}

/* Set a global variable containing the file to write the data to */

void
quantum_objcode_file(char *file)
{
  globalfile = file;
}

/* This function is used as a hook before exiting, as atexit(3) does
   not support to supply arguments to a function */

void
quantum_objcode_exit(char *file)
{
  quantum_objcode_write(0);
  quantum_objcode_stop();
}

/* Execute the contents of an object code file */

void
quantum_objcode_run(char *file, quantum_reg *reg)
{
  int i, j, k, l;
  FILE *fhd;
  unsigned char operation;
  unsigned char buf[OBJBUF_SIZE];
  MAX_UNSIGNED mu;
  double d;

  fhd = fopen(file, "r");

  if(!fhd)
    {
      fprintf(stderr, "quantum_objcode_run: Could not open %s: ", file);
      perror(0);
      return;
    }

  for(i=0; !feof(fhd); i++)
    {
      for(j=0; j<OBJBUF_SIZE; j++)
	buf[j] = 0;
      
      operation = fgetc(fhd);
      switch(operation)
	{
	case INIT:
	  fread(buf, sizeof(MAX_UNSIGNED), 1, fhd);
	  mu = quantum_char2mu(buf);
	  *reg = quantum_new_qureg(mu, 12);
	  break;

	case CNOT:
	case COND_PHASE:
	  fread(buf, sizeof(int), 1, fhd);
	  j = quantum_char2int(buf);
	  fread(buf, sizeof(int), 1, fhd);
	  k = quantum_char2int(buf);
	  switch(operation)
	    {
	    case CNOT: quantum_cnot(j, k, reg);
	      break;
	    case COND_PHASE: quantum_cond_phase(j, k, reg);
	      break;
	    }
	  break;

	case TOFFOLI:
	  fread(buf, sizeof(int), 1, fhd);
	  j = quantum_char2int(buf);
	  fread(buf, sizeof(int), 1, fhd);
	  k = quantum_char2int(buf);
	  fread(buf, sizeof(int), 1, fhd);
	  l = quantum_char2int(buf);
	  quantum_toffoli(j, k, l, reg);
	  break;

	case SIGMA_X:
	case SIGMA_Y:
	case SIGMA_Z:
	case HADAMARD:
	case BMEASURE:
	case BMEASURE_P:
	case SWAPLEADS:
	  fread(buf, sizeof(int), 1, fhd);
	  j = quantum_char2int(buf);
	  switch(operation)
	    {
	    case SIGMA_X: quantum_sigma_x(j, reg);
	      break;
	    case SIGMA_Y: quantum_sigma_y(j, reg);
	      break;
	    case SIGMA_Z: quantum_sigma_z(j, reg);
	      break;
	    case HADAMARD: quantum_hadamard(j, reg);
	      break;
	    case BMEASURE: quantum_bmeasure(j, reg);
	      break;
	    case BMEASURE_P: quantum_bmeasure_bitpreserve(j, reg);
	      break;
	    case SWAPLEADS: quantum_swaptheleads(j, reg);
	      break;
	    }
	  break;

	case ROT_X:
	case ROT_Y:
	case ROT_Z:
	case PHASE_KICK:
	case PHASE_SCALE:
	  fread(buf, sizeof(int), 1, fhd);
	  j = quantum_char2int(buf);
	  fread(buf, sizeof(double), 1, fhd);
	  d = quantum_char2double(buf);
	  switch(operation)
	    {
	    case ROT_X: quantum_r_x(j, d, reg);
	      break;
	    case ROT_Y: quantum_r_y(j, d, reg);
	      break;
	    case ROT_Z: quantum_r_z(j, d, reg);
	      break;
	    case PHASE_KICK: quantum_phase_kick(j, d, reg);
	      break;
	    case PHASE_SCALE: quantum_phase_scale(j, d, reg);
	      break;
	    }
	  break;

	case CPHASE_KICK:
	  fread(buf, sizeof(int), 1, fhd);
	  j = quantum_char2int(buf);
	  fread(buf, sizeof(int), 1, fhd);
	  k = quantum_char2int(buf);
	  fread(buf, sizeof(double), 1, fhd);
	  d = quantum_char2double(buf);
	  quantum_cond_phase_kick(j, k, d, reg);
	  break;
	  
	case MEASURE: quantum_measure(*reg);
	  break;

	case NOP:
	  break;

	default:
	  fprintf(stderr, "%i: Unknown opcode 0x(%X)!\n", i, operation);
	  return;
	}

    }

  fclose(fhd);

}  
