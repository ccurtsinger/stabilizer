#if !defined(RUNTIME_FUNCTION_H)
#define RUNTIME_FUNCTION_H

#include <string.h>
#include <sys/mman.h>

#include "Util.h"
#include "Jump.h"
#include "Trap.h"
#include "Heap.h"
#include "Pile.h"
#include "MemRange.h"

struct Function;

struct FunctionHeader {
private:
    union {
    	uint8_t _jmp[sizeof(Jump)];
        uint8_t _trap[sizeof(Trap)];
    };
    
	Function* _f;
    
public:
    FunctionHeader(Function* f) : _f(f) {}
    
    void jumpTo(void* target) {
        new(_jmp) Jump(target);
    }
    
    void trap() {
        new(_trap) Trap();
    }
    
    Function* getFunction() {
        return _f;
    }
};

struct Function {
private:
    MemRange _code;
    MemRange _table;
    FunctionHeader* _header;
    FunctionHeader _savedHeader;
    
	bool _tableAdjacent;	//< If true, the relocation table should be placed next to the function
	
	uint8_t* _stackPadTable;	//< The base of the 256-entry stack pad table for this function
	
	bool _trapped;			//< If true, the function will trap when called
	
	size_t _lastRelocation;	//< The step number for this function's last relocation
	
	void* _currentLocation;	//< The current location of this function
	
	/**
	 * \brief Place a jump instruction to forward calls to this function
	 * \arg target The destination of the jump instruction
	 */
	inline void forward(void* target) {
        _header->jumpTo(target);
		flush_icache(_header, sizeof(FunctionHeader));

		_trapped = false;
	}
	
public:
	/**
	 * \brief Allocate Function objects on the randomized heap
	 * \arg sz The object size
	 */
	void* operator new(size_t sz) {
		return getDataHeap()->malloc(sz);
	}
	
	/**
	 * \brief Free allocated memory to the randomized heap
	 * \arg p The object base pointer
	 */
	void operator delete(void* p) {
		getDataHeap()->free(p);
	}
	
	/**
	* \brief Create a new runtime representation of a function
	* \arg codeBase The address of the function
	* \arg codeLimit The top of the function
	* \arg tableBase The address of the function's relocation table
	* \arg tableSize The size of the function's relocation table
	* \arg tableAdjacent If true, the relocation table should be placed immediately after the function
	*/
	inline Function(void* codeBase, void* codeLimit, void* tableBase, size_t tableSize, bool tableAdjacent, uint8_t* stackPadTable) :
        _code(codeBase, codeLimit), _table(tableBase, tableSize), _savedHeader(*(FunctionHeader*)_code.base()) {
        
		this->_tableAdjacent = tableAdjacent;
		this->_stackPadTable = stackPadTable;
		this->_lastRelocation = 0;
		this->_currentLocation = NULL;

		// Make the function header writable
		if(mprotect(_code.pageBase(), _code.pageSize(), PROT_READ | PROT_WRITE | PROT_EXEC)) {
			perror("Unable make code writable");
			abort();
		}
        
        // Make a copy of the function header
        _savedHeader = *(FunctionHeader*)_code.base();
        _header = new(_code.base()) FunctionHeader(this);
	}
	
	/**
	 * \brief Free all code locations when deleted
	 */
	inline ~Function() {
		if(_currentLocation != NULL) {
			getCodeHeap()->free(_currentLocation);
		}
	}
	
	/**
	* \brief Relocate this function
	* \arg relocation The global relocation step number.  If this function has already
	*		been relocated in this step, it will not be relocated again.
	* \returns True if the function was moved on this call
	*/
	inline bool relocate(size_t relocation) {
		if(relocation > _lastRelocation) {
			// Allocate space for the new location
			uint8_t* newBase = (uint8_t*)getCodeHeap()->malloc(getAllocationSize());
			
			if(newBase == NULL) {
				perror("code malloc");
				abort();
			}
			
			// If the function hasn't been relocated yet, build the relocated code from parts
			if(_currentLocation == NULL) {
				// Copy the code from the original function
				memcpy(newBase, _code.base(), _code.size());

				// Patch in the saved header, since the original has been overwritten
				*(FunctionHeader*)newBase = _savedHeader;
				
				// If there is a stack pad table, move it to a random location
				if(_stackPadTable != NULL) {
					uintptr_t* table = (uintptr_t*)_table.base();
					for(size_t i=0; i<_table.size(); i+=sizeof(uintptr_t)) {
						if(table[i] == (uintptr_t)_stackPadTable) {
							table[i] = (uintptr_t)getDataHeap()->malloc(256);
						}
					}
				}

				// Copy the relocation table, if needed
				if(_tableAdjacent) {
					memcpy(&newBase[_code.size()], _table.base(), _table.size());
				}

			} else {
				// Copy the code and table (if any) from the previous location
				memcpy(newBase, _currentLocation, getAllocationSize());

				// Put the old location onto the GC pile
				Pile::add(_currentLocation, _code.base(), getAllocationSize());
			}

			// Flush the icache at the new function location
			flush_icache(newBase, _code.size());

			// Record the current location
			_currentLocation = newBase;

			// Redirect the original function to the new location
			forward(_currentLocation);

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
	
	/**
	 * \brief Place a trap instruction at the beginning of this function
	 */
	inline void setTrap() {
		if(!_trapped) {
            _header->trap();
			_trapped = true;
		}
	}
	
	inline void* getCodeBase() {
		return _code.base();
	}
	
	inline size_t getCodeSize() {
		return _code.size();
	}
	
	inline size_t getAllocationSize() {
		if(_tableAdjacent) {
			return _code.size() + _table.size();
		} else {
			return _code.size();
		}
	}
	
	inline void* getCurrentLocation() {
		return _currentLocation;
	}
};

#endif
