/* 
 * File:   StabilizedFunction.h
 * Author: charlie
 *
 * Created on August 21, 2012, 11:04 AM
 */

#ifndef STABILIZEDFUNCTION_H
#define	STABILIZEDFUNCTION_H

#include <map>
#include <vector>

#include "llvm/Module.h"
#include "llvm/Function.h"

using namespace std;
using namespace llvm;

#define ALIGN 64

class StabilizedFunction {
private:
	Function *base;
	Function *next;
	Module *m;
	
	GlobalVariable *info;
	GlobalVariable *name_str;
	GlobalVariable *references_table;

	vector<GlobalValue*> references;
	map<GlobalValue*, Value*> reference_lookups;

	StabilizedFunction(Function *base) {
		this->base = base;
		this->m = base->getParent();
		this->info = NULL;
		this->name_str = NULL;
		this->references_table = NULL;
		
		// Add a dummy function used to compute the size
		next = Function::Create(
			FunctionType::get(Type::getVoidTy(m->getContext()), false),
			GlobalValue::InternalLinkage,
			"stabilizer.dummy."+base->getName()
		);
		
		if(base->getAlignment() < ALIGN) {
			next->setAlignment(ALIGN);
		} else {
			next->setAlignment(base->getAlignment());
		}
		
		// Put a basic block and return instruction into the dummy function
		BasicBlock *dummy_block = BasicBlock::Create(m->getContext(), "", next);
		ReturnInst::Create(m->getContext(), dummy_block);

		// Ensure the dummy is placed immediately after our function
		if(base->getNextNode() == NULL) {
			m->getFunctionList().setNext(base, next);
			m->getFunctionList().addNodeToList(next);
		} else {
			m->getFunctionList().setNext(next, base->getNextNode());
			m->getFunctionList().setNext(base, next);
			m->getFunctionList().addNodeToList(next);
		}
	}

	size_t getReferenceIndex(GlobalValue* value) {
		// Start counting at 2 to leave room for the users counter and runtime object pointer
		size_t index = 2;
		for(vector<GlobalValue*>::iterator g_i = references.begin(); g_i != references.end(); g_i++) {
			if(*g_i == value) {
				return index;
			}

			index++;
		}

		references.push_back(value);
		return references.size() + 1;
	}

	Value* getLocalSlot(size_t index, Instruction *insertion_point, Twine name) {
		// Cast the next function to an i8**
		Value *table = CastInst::CreatePointerCast(next, PointerType::get(PointerType::getInt8PtrTy(m->getContext(), 0), 0), "", insertion_point);

		// Compute a pointer to the given index
		vector<Value*> indices;
		indices.push_back(Constant::getIntegerValue(Type::getInt32Ty(m->getContext()), APInt(32, index, false)));

		GetElementPtrInst *slot = GetElementPtrInst::Create(table, indices, name+".ptr", insertion_point);

		return slot;
	}
	
	GlobalVariable* getNameString() {
		if(name_str == NULL) {
			Constant *str_init = ConstantDataArray::getString(m->getContext(), base->getName(), true);
			name_str = new GlobalVariable(*m, str_init->getType(), true, GlobalVariable::PrivateLinkage, str_init, base->getName()+".name");
		}
		
		return name_str;
	}
	
	GlobalVariable* getReferencesTable() {
		if(references_table == NULL) {
			Twine name = "stabilizer."+base->getName()+"_references";
			references_table = MakeTable(*m, StringRef(name.str()), references);
		}
		
		return references_table;
	}

public:
	static StabilizedFunction* get(Function *f) {
		static map<Function*, StabilizedFunction*> directory;

		if(directory.find(f) == directory.end()) {
			directory[f] = new StabilizedFunction(f);
		}

		return directory[f];
	}
	
	static StructType* getInfoType(Module &m) {
		return StructType::get(
		    Type::getInt8PtrTy(m.getContext()),		// Function name string
			Type::getInt8PtrTy(m.getContext()),		// Pointer to the base of the function
			Type::getInt8PtrTy(m.getContext()),		// Pointer to the next function
			Type::getInt8PtrTy(m.getContext()),		// Pointer to the references table
			NULL
		);
	}

	void makeUseLocal(Use &use) {
		GlobalValue *gv = dyn_cast<GlobalValue>(use.get());
		Instruction *insertion_point = dyn_cast<Instruction>(use.getUser());
		
		// Recursive calls can be skipped
		/*if(gv == base && isa<CallInst>(use.getUser())) {
			return;
		}*/
		
		if(gv != NULL && insertion_point != NULL) {
			PHINode* phi;
			if((phi = dyn_cast<PHINode>(insertion_point)) != NULL) {
				BasicBlock *incoming = phi->getIncomingBlock(use);
				insertion_point = incoming->getTerminator();
			}
			
			// Get or assign an index for the global
			size_t index = getReferenceIndex(gv);
			
			// Get the address of the local pointer
			Value *slot = getLocalSlot(index, insertion_point, gv->getName());
			
			// Load the local pointer
			Value *load = new LoadInst(slot, gv->getName()+".load", insertion_point);
			
			// Cast the local pointer to the appropriate type
			Value *local = BitCastInst::CreatePointerCast(load, gv->getType(), gv->getName(), insertion_point); 
			
			if(isa<PHINode>(use.getUser())) {
				PHINode* phi = dyn_cast<PHINode>(use.getUser());
				BasicBlock* incoming = phi->getIncomingBlock(use);
				while(phi->getBasicBlockIndex(incoming) != -1) {
					phi->removeIncomingValue(incoming, false);
				}
				phi->addIncoming(local, incoming);
			} else {
				use.set(local);
			}
		}
	}
	
	GlobalVariable* getInfo() {
		if(info == NULL) {
			StructType* info_type = StructType::get(
				Type::getInt8PtrTy(m->getContext()),
				Type::getInt8PtrTy(m->getContext()),
				Type::getInt8PtrTy(m->getContext()),
				Type::getInt8PtrTy(m->getContext()),
				NULL
			);

			Constant* info_init = ConstantStruct::get(info_type,
				ConstantExpr::getBitCast(getNameString(), Type::getInt8PtrTy(m->getContext())),
				ConstantExpr::getBitCast(base, Type::getInt8PtrTy(m->getContext())),
				ConstantExpr::getBitCast(next, Type::getInt8PtrTy(m->getContext())),
				ConstantExpr::getBitCast(getReferencesTable(), Type::getInt8PtrTy(m->getContext())),
				NULL
			);
			
			info = new GlobalVariable(*m, info_init->getType(), true, GlobalVariable::InternalLinkage, info_init, "");
		}
		
		return info;
	}

	void trackUsers() {
		Instruction *insertion_point = base->getEntryBlock().getFirstNonPHI();

		// Get a pointer to the counter
		Value *users_ptr_uncast = getLocalSlot(0, insertion_point, "users_ptr");

		// Cast the pointer to the appropriate type
		Value *users_ptr = new BitCastInst(users_ptr_uncast, Type::getInt64PtrTy(m->getContext()), "users_ptr.cast", insertion_point);

		Value *users = new LoadInst(users_ptr, "users", false, insertion_point);
		Value *new_users = BinaryOperator::CreateNUWAdd(
			users,
			Constant::getIntegerValue(Type::getInt64Ty(m->getContext()), APInt(64, 1)),
			"new_users",
			insertion_point
		);
		new StoreInst(new_users, users_ptr, true, insertion_point);

		for(Function::iterator b = base->begin(); b != base->end(); b++) {
			ReturnInst *r = dyn_cast<ReturnInst>(b->getTerminator());
			if(r != NULL) {
				users_ptr_uncast = getLocalSlot(0, r, "users_ptr");
				users_ptr = new BitCastInst(users_ptr_uncast, Type::getInt64PtrTy(m->getContext()), "users_ptr.cast", r);
				users = new LoadInst(users_ptr, "users", false, r);

				new_users = BinaryOperator::CreateNUWSub(users, Constant::getIntegerValue(Type::getInt64Ty(m->getContext()), APInt(64, 1)), "new_users", r);
				new StoreInst(new_users, users_ptr, false, r);
			}
		}
	}

	bool hasRandomAllocas() {
		for(Function::iterator b = base->begin(); b != base->end(); b++) {
			for(BasicBlock::iterator i = b->begin(); i != b->end(); i++) {
				if(isRandomAlloca(&*i)) {
					return true;
				}
			}
		}

		return false;
	}

	bool isRandomAlloca(Value *v) {
		if(isa<AllocaInst>(v)) {
			AllocaInst *a = dyn_cast<AllocaInst>(v);

			if(!a->isArrayAllocation() || isa<Constant>(a->getArraySize())) {
				return true;
			}
		}

		return false;
	}

	size_t getRandomAllocaStructIndex(Value *v) {
		size_t index = 0;
		for(Function::iterator b = base->begin(); b != base->end(); b++) {
			for(BasicBlock::iterator i = b->begin(); i != b->end(); i++) {
				if(isRandomAlloca(&*i)) {
					AllocaInst *a = dyn_cast<AllocaInst>(&*i);

					if(a == v) {
						return index;
					}

					index++;
				}
			}
		}

		return -1;
	}

	Type* getRandomAllocaStructType() {
		vector<Type*> elements;

		for(Function::iterator b = base->begin(); b != base->end(); b++) {
			for(BasicBlock::iterator i = b->begin(); i != b->end(); i++) {
				if(isRandomAlloca(&*i)) {
					AllocaInst *a = dyn_cast<AllocaInst>(&*i);
					elements.push_back(a->getAllocatedType());
				}
			}
		}

		return StructType::get(m->getContext(), ArrayRef<Type*>(elements), false);
	}
};

#endif	/* STABILIZEDFUNCTION_H */

