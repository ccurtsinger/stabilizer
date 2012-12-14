#if !defined(RUNTIME_FUNCTION_H)
#define RUNTIME_FUNCTION_H

#include <string.h>
#include <sys/mman.h>

#include "Util.h"
#include "Jump.h"
#include "Heap.h"
#include "FunctionLocation.h"

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
	
	FunctionLocation* _oldLocation;
	FunctionLocation* _currentLocation;
	
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
		this->_oldLocation = NULL;
		this->_currentLocation = NULL;

		// Make a copy of the function header
		_savedHeader = *(FunctionHeader*)codeBase;

		// Make the function header writable
		if(mprotect(ALIGN_DOWN(_codeBase, PAGESIZE), 2*PAGESIZE, PROT_READ | PROT_WRITE | PROT_EXEC)) {
			perror("Unable make code writable");
			abort();
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
				memcpy(newBase, _currentLocation->getCodeBase(), getAllocationSize());

				// Save the old location
				_oldLocation = _currentLocation;
			}

			// Flush the icache at the new function location
			flush_icache(newBase, _codeSize);

			// Record the current location
			_currentLocation = new FunctionLocation(this, newBase);

			// Redirect the original function to the new location
			forward(newBase);

			// Update the last-relocated counter
			_lastRelocation = relocation;

			return true;

		} else {
			return false;
		}
	}
	
	/**
	 * \brief Update a code pointer (like a return address on the stack)
	 * 
	 * This function first tests to see if p points into this function's current location.
	 * If so, the function will be relocated and p will be updated.  If p points to this
	 * function's old location, the pointer will just be updated.
	 * 
	 * \arg relocation The current relocation step
	 * \arg p The pointer to update
	 * \returns True if the pointer has been updated to point to this function's new location
	 */
	inline bool update(size_t relocation, void** p) {
		if(_currentLocation == NULL) {
			return false;
		}

		intptr_t offset;
		
		if(_oldLocation != NULL) {
			offset = _oldLocation->getOffset(*p);
			if(offset >= 0 && offset < getCodeSize()) {
				assert(_lastRelocation == relocation && "Clean up your mess!");

				// Pointer needs to be updated
				*p = (void*)((uintptr_t)_currentLocation->getCodeBase() + offset);

				return true;
			}
		}
		
		offset = _currentLocation->getOffset(*p);
		if(offset >= 0 && offset < getCodeSize()) {
			// Match!  See if a relocation is required
			if(relocate(relocation)) {
				// Pointer needs to be updated
				*p = (void*)((uintptr_t)_currentLocation->getCodeBase() + offset);
			}

			return true;
		}

		return false;
	}	
	
	/**
	 * \brief Delete any old function locations
	 * This should only be called once any remaining references (like return
	 * addresses on the stack) have been updated to reference the new function
	 * location.
	 */
	inline void cleanup() {
		if(_oldLocation != NULL) {
			delete _oldLocation;
			_oldLocation = NULL;
		}
	}	
	
	/**
	 * \brief Place a trap instruction at the beginning of this function
	 */
	inline void setTrap() {
		if(!_trapped) {
			void** p = (void**)getCodeBase();
			p[0] = TRAP;
			p[1] = this;

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
};

#endif
