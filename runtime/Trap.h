#if !defined(RUNTIME_TRAP_H)
#define RUNTIME_TRAP_H

#include <signal.h>

#include "Arch.h"

struct X86Trap {
    uint8_t trap_opcode;
    
    enum { TrapSignal = SIGTRAP };
    enum { TrapAdjust = 1 };
    
    X86Trap() {
        trap_opcode = 0xCC;
    }
    
} __attribute__((packed));

struct PPCTrap {
    uint32_t trap_opcode;
    
    enum { TrapSignal = SIGILL };
    enum { TrapAdjust = 0 };
    
    PPCTrap() {
        trap_opcode = 0x0;
    }
    
} __attribute__((packed));

#if IS_X86
	typedef X86Trap Trap;
#elif IS_X86_64
	typedef X86Trap Trap;
#elif IS_PPC
	typedef PPCTrap Trap;
#endif

#endif
