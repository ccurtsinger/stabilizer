#if !defined(RUNTIME_MEMRANGE_H)
#define RUNTIME_MEMRANGE_H

#include "Util.h"

struct MemRange {
private:
    uintptr_t _base;
    uintptr_t _limit;
    
public:
    inline MemRange(void* base, size_t size) {
        _base = (uintptr_t)base;
        _limit = _base + size;
    }
    
    inline MemRange(void* base, void* limit) {
        _base = (uintptr_t)base;
        _limit = (uintptr_t)limit;
    }
    
    inline void* base() {
        return (void*)_base;
    }
    
    inline void* pageBase() {
        return (void*)(_base - _base % PAGESIZE);
    }
    
    inline void* pageLimit() {
        uintptr_t l = _limit + PAGESIZE - 1;
        return (void*)(l - l % PAGESIZE);
    }
    
    inline size_t pageSize() {
        return (uintptr_t)pageLimit() - (uintptr_t)pageBase();
    }
    
    inline void* limit() {
        return (void*)_limit;
    }
    
    inline size_t size() {
        return (size_t)(_limit - _base);
    }
    
    inline size_t offsetOf(void* p) {
        return (uintptr_t)p - _base;
    }
    
    inline void* offsetIn(size_t offset) {
        return (void*)(_base + offset);
    }
    
    inline bool contains(void* p) {
        return offsetOf(p) < size();
    }
};

#endif
