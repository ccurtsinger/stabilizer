#include <execinfo.h>
#include "Debug.h"
#include "FunctionLocation.h"

void panic() {
    void* real_buffer[100];
    void* adjusted_buffer[100];
    
    size_t num = backtrace(real_buffer, 100);
    
    for(size_t i=0; i<num; i++) {
        adjusted_buffer[i] = FunctionLocation::adjust(real_buffer[i]);
    }
    
    char** strings = backtrace_symbols(adjusted_buffer, num);
    
    if(strings == NULL) {
        perror("backtrace_symbols");
        abort();
    }
    
    for(size_t i=0; i<num; i++) {
        printf("%s [at %p]\n", strings[i], real_buffer[i]);
    }
    
    free(strings);
}
