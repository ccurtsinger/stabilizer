//
//  Global.h
//  stabilizer2
//
//  Created by Charlie Curtsinger on 9/13/11.
//  Copyright 2011 University of Massachusetts. All rights reserved.
//

#ifndef stabilizer2_Global_h
#define stabilizer2_Global_h

#include <string.h>
#include <stdint.h>

#include "Metadata.h"
#include "Heaps.h"
//#include "map.h"

#include <map>
#include <utility>

using namespace std;

namespace stabilizer {

	class Global;

	//typedef map<void*, Global*, DH_malloc, DH_free> GlobalMapType;
	typedef map<void*, Global*> GlobalMapType;

	class Global : public Metadata {
	private:
		void *original;
		void *relocated;
		size_t size;

	public:
		Global(void *original, size_t size) {
			this->original = original;
			this->relocated = NULL;
			this->size = size;
		}

		void* getOriginalBase() {
			return this->original;
		}

		void* getRelocatedBase() {
			if(relocated == NULL) {
				relocated = DH_malloc(size);
				memcpy(relocated, original, size);
			}

			return relocated;
		}
	};
}

#endif
