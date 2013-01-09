/* objcode.h: Object code declarations and definitions

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

#ifndef __OBJCODE_H

#define __OBJCODE_H

#include "config.h"
#include "qureg.h"

#define OBJCODE_PAGE 65536
#define OBJBUF_SIZE 80

#define INIT        0x00
#define CNOT        0x01
#define TOFFOLI     0x02
#define SIGMA_X     0x03
#define SIGMA_Y     0x04
#define SIGMA_Z     0x05
#define HADAMARD    0x06
#define ROT_X       0x07
#define ROT_Y       0x08
#define ROT_Z       0x09
#define PHASE_KICK  0x0A
#define PHASE_SCALE 0x0B
#define COND_PHASE  0x0C
#define CPHASE_KICK 0x0D
#define SWAPLEADS   0x0E

#define MEASURE     0x80
#define BMEASURE    0x81
#define BMEASURE_P  0x82

#define NOP         0xFF

extern MAX_UNSIGNED quantum_char2mu(unsigned char *buf);
extern int quantum_char2int(unsigned char *buf);
extern double quantum_char2double(unsigned char *buf);
extern void quantum_objcode_start();
extern void quantum_objcode_stop();
extern int quantum_objcode_put(unsigned char operation, ...);
extern int quantum_objcode_write(char *file);
extern void quantum_objcode_file(char *file);
extern void quantum_objcode_exit(char *file);
extern void quantum_objcode_run(char *file, quantum_reg *reg);

#endif
