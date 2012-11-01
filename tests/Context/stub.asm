global _stub

extern _foo
extern _baz

BITS 64

_stub:
    ;lea rax, [rip-7]
    lea rax, [_foo wrt rip]
    sub rsp, 8
    mov [rsp], rax
    jmp _baz
