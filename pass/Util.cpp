#include <iostream>
#include <vector>
#include <set>
#include <sstream>

#include "Util.h"

using namespace std;
using namespace llvm;

Function* MakeConstructor(Module &m, StringRef name) {
	// Void type
	Type* void_t = Type::getVoidTy(m.getContext());

	// 32 bit integer type
	Type* i32_t = Type::getInt32Ty(m.getContext());

	// Constructor function type
	FunctionType* ctor_fn_t = FunctionType::get(void_t, false);
	PointerType* ctor_fn_p_t = PointerType::get(ctor_fn_t, 0);

	// Constructor table entry type
	StructType* ctor_entry_t = StructType::get(i32_t, ctor_fn_p_t, NULL);

	// Create constructor function
	Function *init = Function::Create(ctor_fn_t, Function::InternalLinkage, name, &m);

	// Sequence of constructor table entries
	vector<Constant*> ctor_entries;

	// Add the entry for the new constructor
	ctor_entries.push_back(
		ConstantStruct::get(ctor_entry_t,
			ConstantInt::get(i32_t, 65535, false),
			init,
			NULL
		)
	);
	
	// find the current constructor table
	GlobalVariable *ctors = m.getGlobalVariable("llvm.global_ctors", false);

	// if found, copy the entries from the current ctor table to the new one
	if(ctors) {
		Constant *initializer = ctors->getInitializer();
		ConstantArray *ctor_array_const = dyn_cast<ConstantArray>(initializer);
		
		if(!ctor_array_const) {
			cerr<<"warning: llvm.global_ctors is not a constant array"<<endl;
		} else {
			for(ConstantArray::op_iterator opi = ctor_array_const->op_begin(); opi != ctor_array_const->op_end(); opi++) {
				ConstantStruct *entry = dyn_cast<ConstantStruct>(opi->get());
				ctor_entries.push_back(entry);
			}
		}
	}

	// set up the constant initializer for the new constructor table
	Constant *ctor_array_const = ConstantArray::get(
		ArrayType::get(
			ctor_entries[0]->getType(),
			ctor_entries.size()
		),
		ctor_entries
	);

	// create the new constructor table
	GlobalVariable *new_ctors = new GlobalVariable(
		m,
		ctor_array_const->getType(),
		true,
		GlobalVariable::AppendingLinkage,
		ctor_array_const,
		""
	);

	// give the new constructor table the appropriate name, taking it from the current table if one exists
	if(ctors) {
		new_ctors->takeName(ctors);
		ctors->setName("old.llvm.global_ctors");
		ctors->setLinkage(GlobalVariable::PrivateLinkage);
	} else {
		new_ctors->setName("llvm.global_ctors");
	}
	
	return init;
}
