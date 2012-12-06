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

set<Instruction*> Instructify(Value *v) {
	set<Instruction*> result;
	
	Instruction* i;
	Constant* c;

	if((i = dyn_cast<Instruction>(v)) != NULL) {
		result.insert(i);
		
	} else if((c = dyn_cast<Constant>(v)) != NULL) {
		vector<Use*> uses;
		for(Constant::use_iterator u = c->use_begin(); u != c->use_end(); u++) {
			uses.push_back(&u.getUse());
		}
		
		for(vector<Use*>::iterator use_iter = uses.begin(); use_iter != uses.end(); use_iter++) {
			Use *use = *use_iter;
			User *user = use->getUser();
			
			set<Instruction*> instructions = Instructify(user);
			for(set<Instruction*>::iterator inst_iter = instructions.begin(); inst_iter != instructions.end(); inst_iter++) {
				Instruction *inst = *inst_iter;
				
				Instruction *instructified = NULL;
				
				ConstantExpr* e;

				if((e = dyn_cast<ConstantExpr>(v)) != NULL) {
					vector<Value*> ops;
					for(size_t x=0; x<e->getNumOperands(); x++) {
						ops.push_back(e->getOperand(x));
					}
					
					Instruction *insertion_point = inst;
					PHINode* phi;

					if((phi = dyn_cast<PHINode>(inst)) != NULL) {
						insertion_point = phi->getIncomingBlock(*use)->getTerminator();
					}
					
					if(e->getOpcode() == Instruction::GetElementPtr) {
						Value** ops_array = new Value*[ops.size()-1];
						for(size_t i=1; i<ops.size(); i++) {
							ops_array[i-1] = ops[i];
						}

						instructified = GetElementPtrInst::Create(ops[0], ArrayRef<Value*>(ops_array, ops.size()-1), "", insertion_point);
						
					} else if(e->getOpcode() == Instruction::BitCast) {
						instructified = new BitCastInst(ops[0], v->getType(), "", insertion_point);
						
					} else if(e->getOpcode() == Instruction::PtrToInt) {
						instructified = new PtrToIntInst(ops[0], v->getType(), "", insertion_point);
						
					} else {
						errs()<<"  Unhandled ConstantExpr type "<<e->getOpcodeName()<<"\n";
					}
					
				} else if(dyn_cast<GlobalValue>(v) || dyn_cast<ConstantInt>(v) || dyn_cast<ConstantFP>(v)) {
					// Globals and literals are evaluated statically, so leave them as-is
				
				} else {
					errs()<<"  Unhandled Constant Type\n";
				}
				
				if(instructified != NULL) {
					for(Value::use_iterator u = v->use_begin(); u != v->use_end(); u++) {
						if(u.getUse().getUser() == inst) {
							u.getUse().set(instructified);
						}
					}
					
					if(c->getNumUses() == 0) {
						c->destroyConstant();
					}
					
					result.insert(instructified);
				}
			}
		}
	} else {
		errs()<<"  Unhandled Value Type\n";
	}
	
	return result;
}

void GlobifyFloats(Module &m, Value *v) {
	ConstantExpr* e;
	ConstantFP* f;

	if((e = dyn_cast<ConstantExpr>(v)) != NULL) {
		
		for(ConstantExpr::op_iterator op = e->op_begin(); op != e->op_end(); op++) {
			GlobifyFloats(m, op->get());
		}	
		
	} else if((f = dyn_cast<ConstantFP>(v)) != NULL) {
		Instructify(f);
		GlobalVariable *gv = new GlobalVariable(m, v->getType(), true, GlobalVariable::InternalLinkage, f, "fconst");
		
		vector<Use*> uses;
		for(Constant::use_iterator u = f->use_begin(); u != f->use_end(); u++) {
			uses.push_back(&u.getUse());
		}
		
		for(vector<Use*>::iterator use_iter = uses.begin(); use_iter != uses.end(); use_iter++) {
			Use* use = *use_iter;
			User *user = use->getUser();
				
			Instruction* i = dyn_cast<Instruction>(user);
			if(i != NULL) {
				Instruction *insertion_point = i;
				
				PHINode* phi = dyn_cast<PHINode>(user);
				if(phi != NULL) {
					insertion_point = phi->getIncomingBlock(*use)->getTerminator();
				}
				
				LoadInst *load = new LoadInst(gv, "", insertion_point);
				if(phi != NULL) {
					BasicBlock* b = phi->getIncomingBlock(*use);
					int index = phi->getBasicBlockIndex(b);
					phi->removeIncomingValue(b, false);
					if(phi->getBasicBlockIndex(b) == -1) {
						phi->addIncoming(load, b);
					} else {
						// Something bad has happened.  Need to handle it here
						phi->addIncoming(load, b);
					}
				} else {
					use->set(load);
				}
			}
		}
	}
}
