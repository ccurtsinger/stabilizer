global _stub
global _stubSize
global _saveState

extern _doStuff

BITS 64

_stub:
    lea rax, [rip-7]
    sub rsp, 8
    mov [rsp], rax
.end

_stubSize:
	dq _stub.end - _stub

_saveState:
	push rbp
	mov rbp, rsp
    push r15
    push r14
    push r13
    push r12
    push r11
    push r10
    push r9
    push r8
    push rsi
    push rdi
    push rdx
    push rcx
    push rbx
    push rax
    
    mov rdi, 8[rbp]
    lea rsi, (_stub.end - _stub)[rdi]
    call _doStuff
    
    pop rax
    pop rbx
    pop rcx
    pop rdx
    pop rdi
    pop rsi
    pop r8
    pop r9
    pop r10
    pop r11
    pop r12
    pop r13
    pop r14
    pop r15
    pop rbp
    ret
