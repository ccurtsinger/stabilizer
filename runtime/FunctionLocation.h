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

namespace stabilizer {

	class Function;
	
	class FunctionLocation : public Metadata {
	private:
		Function *function;
		void *base;

	public:
		FunctionLocation(Function *function);

		FunctionLocation(Function *function, void *base);

		Function* getFunction() {
			return function;
		}

		void* getBase() {
			return base;
		}

		void decrementUsers();

		size_t getUsers();

		bool isOriginal();
	};
}

#endif
