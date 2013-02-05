#include "Heap.h"

DataHeapType* getDataHeap() {
    static char buf[sizeof(DataHeapType)];
    static DataHeapType* _theDataHeap = new (buf) DataHeapType;
    return _theDataHeap;
}

CodeHeapType* getCodeHeap() {
    static char buf[sizeof(CodeHeapType)];
    static CodeHeapType* _theCodeHeap = new (buf) CodeHeapType;
    return _theCodeHeap;
}
