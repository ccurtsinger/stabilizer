#include "Function.h"
#include "FunctionLocation.h"

Function::~Function() {
    if(_current != NULL) {
        _current->release();
    }
}

void Function::copyTo(void* target) {
    if(_current == NULL) {
        // Copy the code from the original function
        memcpy(target, _code.base(), _code.size());

        // Patch in the saved header, since the original has been overwritten
        *(FunctionHeader*)target = _savedHeader;

        // If there is a stack pad table, move it to a random location
        if(_stackPadTable != NULL) {
            uintptr_t* table = (uintptr_t*)_table.base();
            for(size_t i=0; i<_table.size(); i+=sizeof(uintptr_t)) {
                if(table[i] == (uintptr_t)_stackPadTable) {
                    _stackPadTable = (uint8_t*)getDataHeap()->malloc(256);
                    table[i] = (uintptr_t)_stackPadTable;
                }
            }
        }

        // Copy the relocation table, if needed
        if(_tableAdjacent) {
            uint8_t* a = (uint8_t*)target;
            memcpy(&a[_code.size()], _table.base(), _table.size());
        }
    } else {
        memcpy(target, _current->_memory.base(), getAllocationSize());
    }
}

bool Function::relocate(size_t relocation) {
    if(relocation > _lastRelocation) {
        FunctionLocation* oldLocation = _current;
        _current = new FunctionLocation(this);
        _current->activate();

        if(oldLocation != NULL) {
            oldLocation->release();
        }

        // Update the last-relocated counter
        _lastRelocation = relocation;

        // Fill the stack pad table with random bytes
        if(_stackPadTable != NULL) {
            for(size_t i=0; i<256; i++) {
                _stackPadTable[i] = getRandomByte();
            }
        }

        return true;

    } else {
        return false;
    }
}
