#if !defined(RUNTIME_CONTEXT_H)
#define RUNTIME_CONTEXT_H

#if !defined(_XOPEN_SOURCE)
// Digging inside of ucontext_t is deprecated unless this macros is defined
#define _XOPEN_SOURCE
#endif

#include <stdint.h>
#include <sys/mman.h>
#include <ucontext.h>

#include "Arch.h"

struct Stack {
private:
    void** _frame;
    
public:
    inline Stack(void* frame) : _frame((void**)frame) {}
    
    inline void*& ret() {
        return _frame[1];
    }
    
    inline void*& fp() {
        return _frame[0];
    }
    
    inline void operator++(int) {
        _frame = (void**)fp();
    }
};

struct Context {
private:
    ucontext_t* _c;
    Context(void* c) : _c((ucontext_t*)c) {}
    
public:
    inline void*& ip() {
        _OSX(_AnyX86(return *(void**)&_c->uc_mcontext->__ss.__rip));
        _LINUX(_AnyX86(return *(void**)&_c->uc_mcontext.gregs[REG_RIP]));
        _LINUX(_PPC(return *(void**)&_c->uc_mcontext.regs->nip));
        
        ABORT("Instruction pointer not available on current target");
    }
    
    inline void*& sp() {
        _OSX(_AnyX86(return *(void**)&_c->uc_mcontext->__ss.__rsp));
        _LINUX(_AnyX86(return *(void**)&_c->uc_mcontext.gregs[REG_RSP]));
        _LINUX(_PPC(return *(void**)&_c->uc_mcontext.regs->gpr[PT_R1]));
        
        ABORT("Stack pointer not available on current target");
    }
    
    inline void*& fp() {
        _OSX(_AnyX86(return *(void**)&_c->uc_mcontext->__ss.__rbp));
        _LINUX(_AnyX86(return *(void**)&_c->uc_mcontext.gregs[REG_RBP]));
        _LINUX(_PPC(return *(void**)&_c->uc_mcontext.regs->gpr[PT_R1]));
        
        ABORT("Frame pointer not available on current target");
    }
    
    inline Stack stack() {
        return Stack(fp());
    }
};

#endif
