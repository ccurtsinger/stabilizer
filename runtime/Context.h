/**
 * Signal context and stack-walking code
 */

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

/**
 * A stack walking iterator
 */
struct Stack {
private:
    /// A pointer to the current stack frame
    void** _frame;
    
public:
    /**
     * Initialize a stack with a frame address
     * \arg frame The starting frame pointer
     */
    inline Stack(void* frame) : _frame((void**)frame) {}
    
    /**
     * Get the return address from the current frame
     * \returns A reference to the return address
     */
    inline void*& ret() {
        return _frame[1];
    }
    
    /**
     * Get the next frame pointer up the stack
     * \returns A reference to the next frame pointer
     */
    inline void*& fp() {
        return _frame[0];
    }
    
    /**
     * Move up to the next frame
     */
    inline void operator++(int) {
        _frame = (void**)fp();
    }
};

struct Context {
private:
    /// The actual signal context
    ucontext_t* _c;
    
    Context(void* c) : _c((ucontext_t*)c) {}
    
public:
    /**
     * Get a reference to the context instruction pointer
     * \returns A reference to the instruction pointer
     */
    inline void*& ip() {
        _OSX(_AnyX86(return *(void**)&_c->uc_mcontext->__ss.__rip));
        _LINUX(_AnyX86(return *(void**)&_c->uc_mcontext.gregs[REG_RIP]));
        _LINUX(_PPC(return *(void**)&_c->uc_mcontext.regs->nip));
        
        ABORT("Instruction pointer not available on current target");
    }
    
    /**
     * Get a reference to the context stack pointer
     * \returns A reference to the stack pointer
     */
    inline void*& sp() {
        _OSX(_AnyX86(return *(void**)&_c->uc_mcontext->__ss.__rsp));
        _LINUX(_AnyX86(return *(void**)&_c->uc_mcontext.gregs[REG_RSP]));
        _LINUX(_PPC(return *(void**)&_c->uc_mcontext.regs->gpr[PT_R1]));
        
        ABORT("Stack pointer not available on current target");
    }
    
    /**
     * Get a reference to the context frame pointer
     * \returns A reference to the frame pointer
     */
    inline void*& fp() {
        _OSX(_AnyX86(return *(void**)&_c->uc_mcontext->__ss.__rbp));
        _LINUX(_AnyX86(return *(void**)&_c->uc_mcontext.gregs[REG_RBP]));
        _LINUX(_PPC(return *(void**)&_c->uc_mcontext.regs->gpr[PT_R1]));
        
        ABORT("Frame pointer not available on current target");
    }
    
    /**
     * Get an iterator to walk the context's stack
     * \returns A Stack iterator
     */
    inline Stack stack() {
        return Stack(fp());
    }
};

#endif
