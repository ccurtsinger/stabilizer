//
//  FunctionLocation.h
//  stabilizer2
//
//  Created by Charlie Curtsinger on 9/13/11.
//  Copyright 2011 University of Massachusetts. All rights reserved.
//

#ifndef stabilizer2_FunctionLocation_h
#define stabilizer2_FunctionLocation_h

#include "Metadata.h"
#include "Heaps.h"

namespace stabilizer {

	class Function;
	
	class FunctionLocation : public Metadata {
	private:
		Function* function;
		void* base;
		void* allocated_base;

	public:
		size_t defunctCount;
		
		FunctionLocation(Function* function);
		FunctionLocation(Function* function, void* base, void* allocated_base);
		~FunctionLocation() {
			if(!isOriginal()) {
				Code_free(getAllocatedBase());
			}
		}

		Function* getFunction() {
			return function;
		}

		void* getBase() {
			return base;
		}
		
		void* getAllocatedBase() {
			return allocated_base;
		}

		void decrementUsers();

		size_t getUsers();

		bool isOriginal();
	};
}

#endif
