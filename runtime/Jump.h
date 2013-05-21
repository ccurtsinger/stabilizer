#ifndef RUNTIME_JUMP_H
#define RUNTIME_JUMP_H

#include <new>
#include <stdint.h>

#include "Arch.h"
#include "Debug.h"

struct X86Jump32 {
    volatile uint8_t jmp_opcode;
    volatile uint32_t jmp_offset;

    X86Jump32(void *target) {
        jmp_opcode = 0xE9;
        jmp_offset = (uint32_t)((intptr_t)target - (intptr_t)this) - sizeof(struct X86Jump32);
    }

} __attribute__((packed));

struct X86Jump64 {
    volatile uint32_t sub_8_rsp;
    volatile uint32_t mov_imm_0rsp;
    volatile uint32_t target_low;
    volatile uint32_t mov_imm_4rsp;
    volatile uint32_t target_high;
    volatile uint8_t retq;

    X86Jump64(void *target) {
        /* x86_64 doesn't have an immediate 64 bit jump, so build one:
         *  1. Move down 8 bytes on the stack
         *  2. Put the target address on the stack in 32 bit chunks
         *  3. Return
         */
        sub_8_rsp = 0x08EC8348;     // move the stack pointer down 8 bytes
        mov_imm_0rsp = 0x002444C7;  // move an immediate to 0(%rsp)
        target_low = (uint32_t)(int64_t)target;
        mov_imm_4rsp = 0x042444C7;  // move an immediate to 4(%rsp)
        target_high = (uint32_t)((int64_t)target >> 32);
        retq = 0xC3;
    }
} __attribute__((packed));

struct X86_64Jump {
    union {
        uint8_t jmp32[sizeof(X86Jump32)];
        uint8_t jmp64[sizeof(X86Jump64)];
    };
    
    X86_64Jump(void *target) {
        if((uintptr_t)target - (uintptr_t)this <= 0x00000000FFFFFFFFu || (uintptr_t)this - (uintptr_t)target <= 0x00000000FFFFFFFFu) {
            new(this) X86Jump32(target);
        } else {
            new(this) X86Jump64(target);
        }
    }
} __attribute__((packed));

struct PPCJump {
    union {
        uint32_t ba;
        struct{
            volatile uint32_t lis_to_r0;
            volatile uint32_t ori_r0;
            volatile uint32_t mtctr;
            volatile uint32_t bctr;
        };
    } __attribute__((packed));

    PPCJump(void *target) {
        uintptr_t t = (uintptr_t)target;
        uintptr_t pos_offset = t - (uintptr_t)this;
        intptr_t neg_offset = (intptr_t)this - (intptr_t)t;

        /*if(t < 1<<25) {
            DEBUG("absolute jump");
            ba = 0x48000002;
            ba |= t & 0x03FFFFFCu;
        } else if(pos_offset < 1<<25) {
            DEBUG("  use positive offset");
            ba = 0x48000000;
            ba |= (uint32_t)pos_offset & 0x03FFFFFC;
        } else if(-neg_offset < 1<<25) {
            DEBUG("  use negative offset\n");
            ba = 0x48000000;
            ba |= neg_offset & 0x03FFFFFC;
        } else { */
            DEBUG("slow jump");
            lis_to_r0=0x3c000000 | ((t>>16)&0xFFFFu);
            ori_r0=0x60000000 | (t&0xFFFFu);
            mtctr=0x7c0903a6;
            bctr=0x4e800420;
        // }
    }
} __attribute__((packed));

#if IS_X86
typedef X86Jump32 Jump;
#elif IS_X86_64
typedef X86_64Jump Jump;
#elif IS_PPC
typedef PPCJump Jump;
#endif

#endif
