#include <stdio.h>
#include <signal.h>
#include <sys/mman.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <new>

#include "Util.h"
#include "Jump.h"

using namespace std;

extern "C" uint8_t saveState;
extern "C" uint8_t stub;
extern "C" size_t stubSize;

void foo(int x, int y, int z) {
	char buf[512];
    sprintf(buf, "in foo: %x %x %x\n", x, y, z);
}

void bar(int x, int y, int z) {
	char buf[512];
	sprintf(buf, "in bar: %x %x %x\n", x, y, z);
}

void placeStub(void* p) {
	size_t copySize = stubSize + sizeof(X86Jump64) + sizeof(void*);
    
    void* base = ALIGN_DOWN(p, PAGESIZE);
    void* limit = ALIGN_UP((uintptr_t)p + copySize, PAGESIZE);
    size_t size = (uintptr_t)limit - (uintptr_t)base;

    if(mprotect(base, size, PROT_READ | PROT_WRITE | PROT_EXEC)) {
    	perror("mprotect");
    }
    
    uint8_t* restore = new uint8_t[copySize];
    memcpy(restore, (void*)p, copySize);
    
    uint8_t* x = (uint8_t*)p;
    
    memcpy((void*)x, (void*)&stub, stubSize);
    x += stubSize;
    
    new(x) Jump((void*)&saveState);
    x += sizeof(X86Jump64);
    
    *(void**)x = restore;
}

void placeTrap(void* p) {
	size_t copySize = stubSize + sizeof(X86Jump64) + sizeof(void*);
    
    void* base = ALIGN_DOWN(p, PAGESIZE);
    void* limit = ALIGN_UP((uintptr_t)p + copySize, PAGESIZE);
    size_t size = (uintptr_t)limit - (uintptr_t)base;

    if(mprotect(base, size, PROT_READ | PROT_WRITE | PROT_EXEC)) {
    	perror("mprotect");
    }
    
    uint8_t* restore = new uint8_t[copySize];
    memcpy(restore, (void*)p, copySize);
    
    uint8_t* x = (uint8_t*)p;
    
    *x = 0xCC;
    x += stubSize + sizeof(X86Jump64);
    
    *(void**)x = restore;
}

extern "C" void doStuff(void* source, void* restore) {
	/*int count = 0;
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
    }*/
    
    size_t restoreSize = stubSize + sizeof(X86Jump64) + sizeof(void*);
    uint8_t** restorePtr = (uint8_t**)((uintptr_t)source + restoreSize - sizeof(void*));
    
    memcpy((void*)source, *restorePtr, restoreSize);
}

void trap(int sig, siginfo_t *info, void *c) {
	void* restore = (void*)GET_CONTEXT_IP(c);
	void* source = (void*)((uintptr_t)restore - 1);
	SET_CONTEXT_IP(c, (uintptr_t)source);
	
    doStuff(source, restore);
}

int main(int argc, char** argv) {
    struct sigaction sa;
    sa.sa_sigaction = &trap;
    sa.sa_flags = SA_SIGINFO;
    sigaction(SIGTRAP, &sa, NULL);
    
    /*placeStub((void*)foo);
    placeTrap((void*)bar);
    
    foo(0x12345, 0xABCDE, 0xD00FCA75);
    bar(0x12345, 0xABCDE, 0xD00FCA75);*/
    
    uint8_t* p = &stub;
    for(int i=0; i<stubSize; i++) {
    	printf("%x ", *p);
    	p++;
    }
    
    for(int i=0; i<1; i++) {
    	placeTrap((void*)foo);
    	foo(0x12345, 0xABCDE, 0xD00FCA75);
    }
    
	return 0;
}
