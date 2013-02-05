#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>

extern "C" {
    float powif(float b, int e) {
        return powf(b, (float)e);
    }
    
    void memset_i32(void* p, uint8_t val, uint32_t len, uint32_t align, bool isvolatile) {
        memset(p, val, len);
    }

    void memset_i64(void* p, uint8_t val, uint64_t len, uint32_t align, bool isvolatile) {
        memset(p, val, len);
    }
}
