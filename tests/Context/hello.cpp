#include <stdio.h>

//extern "C" void stub(int x, int y, int z);

extern "C" void stub(int x, int y, int z);

extern "C" void foo(int x, int y, int z) {
    printf("in foo: %x %x %x\n", x, y, z);
}

extern "C" void baz() {
    __asm__("push %r15");
    __asm__("push %r14");
    __asm__("push %r13");
    __asm__("push %r12");
    __asm__("push %r11");
    __asm__("push %r10");
    __asm__("push %r9");
    __asm__("push %r8");
    __asm__("push %rsi");
    __asm__("push %rdi");
    __asm__("push %rdx");
    __asm__("push %rcx");
    __asm__("push %rbx");
    
    int count = 0;
    int primes[100];
    
    for(int x=2; count<100; x++) {
        bool is_prime = true;
        for(int d=0; d<count && is_prime; d++) {
            if(x % primes[d] == 0) {
                is_prime = false;
            }
        }
        
        if(is_prime) {
            primes[count] = x;
            count++;
        }
    }
    
    for(int i=0; i<100; i++) {
        printf("%d ", primes[i]);
    }
    
    __asm__("pop %rbx");
    __asm__("pop %rcx");
    __asm__("pop %rdx");
    __asm__("pop %rdi");
    __asm__("pop %rsi");
    __asm__("pop %r8");
    __asm__("pop %r9");
    __asm__("pop %r10");
    __asm__("pop %r11");
    __asm__("pop %r12");
    __asm__("pop %r13");
    __asm__("pop %r14");
    __asm__("pop %r15");
}

int main(int argc, char** argv) {
	printf("Hello World!\n");
    stub(0x12345, 0xABCDE, 0xD00FCA75);
    printf("zonk\n");
    
    printf("main: %p\n", main);
    printf("foo: %p\n", foo);
    printf("baz: %p\n", baz);
    printf("stub: %p\n", stub);
    
	return 0;
}
