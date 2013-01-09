#if !defined(RUNTIME_FUNCTION_H)
#define RUNTIME_FUNCTION_H

#include <string.h>
#include <sys/mman.h>

#include "Util.h"
#include "Jump.h"
#include "Heap.h"
#include "Pile.h"

union FunctionHeader {
	uint8_t jmp[sizeof(Jump)];
	
	struct {
		void* trap;
		void* obj;
	};
};

struct Function {
private:
	void* _codeBase;		//< The address of the function
	size_t _codeSize;		//< The size of the function (code only)
	
	void* _tableBase;		//< The address of this function's relocation table
	size_t _tableSize;		//< The size of this function's relocation table
	bool _tableAdjacent;	//< If true, the relocation table should be placed next to the function
	
	FunctionHeader _savedHeader;	//< The original contents of the function header
	bool _trapped;			//< If true, the function will trap when called
	
	size_t _lastRelocation;	//< The step number for this function's last relocation
	
	void* _currentLocation;	//< The current location of this function
	
	/**
	 * \brief Place a jump instruction to forward calls to this function
	 * \arg target The destination of the jump instruction
	 */
	inline void forward(void* target) {
		new(getCodeBase()) Jump(target);
		flush_icache(getCodeBase(), sizeof(Jump));

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
	inline Function(void* codeBase, void* codeLimit, void* tableBase, size_t tableSize, bool tableAdjacent) {
		this->_codeBase = codeBase;
		this->_codeSize = (uintptr_t)codeLimit - (uintptr_t)codeBase;
		this->_tableBase = tableBase;
		this->_tableSize = tableSize;
		this->_tableAdjacent = tableAdjacent;
		this->_lastRelocation = 0;
		this->_currentLocation = NULL;

		// Make a copy of the function header
		_savedHeader = *(FunctionHeader*)codeBase;

		// Make the function header writable
		if(mprotect(ALIGN_DOWN(_codeBase, PAGESIZE), PAGESIZE + (size_t)ALIGN_UP(_codeSize, PAGESIZE), PROT_READ | PROT_WRITE | PROT_EXEC)) {
			perror("Unable make code writable");
			abort();
		}
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
	 * Check the integrity of the current function location
	 */
	inline void selfCheck() {
		if(_currentLocation != NULL && _tableAdjacent) {
			uint8_t* p = (uint8_t*)_currentLocation;
			for(size_t i=0; i<_tableSize; i++) {
				assert(p[_codeSize+i] == ((uint8_t*)_tableBase)[i]);
			}
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
				memcpy(newBase, _codeBase, _codeSize);

				// Patch in the saved header, since the original has been overwritten
				*(FunctionHeader*)newBase = _savedHeader;

				// Copy the relocation table, if needed
				if(_tableAdjacent) {
					memcpy(&newBase[_codeSize], _tableBase, _tableSize);
				}

			} else {
				// Copy the code and table (if any) from the previous location
				memcpy(newBase, _currentLocation, getAllocationSize());

				// TODO: Put the old location onto the GC pile
				//printf("Discarding code location at %p\n", _currentLocation);
				Pile::add(_currentLocation, getAllocationSize());
			}

			// Flush the icache at the new function location
			flush_icache(newBase, _codeSize);

			// Record the current location
			_currentLocation = newBase;

			// Redirect the original function to the new location
			forward(_currentLocation);

			// Update the last-relocated counter
			_lastRelocation = relocation;

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
			FunctionHeader* header = (FunctionHeader*)getCodeBase();
			header->trap = TRAP;
			header->obj = this;

			_trapped = true;
		}
	}
	
	inline void* getCodeBase() {
		return _codeBase;
	}
	
	inline size_t getCodeSize() {
		return _codeSize;
	}
	
	inline size_t getAllocationSize() {
		if(_tableAdjacent) {
			return _codeSize + _tableSize;
		} else {
			return _codeSize;
		}
	}
	
	inline void* getCurrentLocation() {
		return _currentLocation;
	}
};

#endif
