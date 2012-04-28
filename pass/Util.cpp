#include <iostream>
#include <vector>
#include <set>
#include <sstream>

#include "Util.h"

using namespace std;
using namespace llvm;

GlobalVariable* MakeTable(Module &m, StringRef name, vector<GlobalValue*> values) {
	vector<Constant*> constants;
	for(vector<GlobalValue*>::iterator v_iter = values.begin(); v_iter != values.end(); v_iter++) {
		GlobalValue *v = *v_iter;
		constants.push_back(ConstantExpr::getBitCast(v, Type::getInt8PtrTy(m.getContext())));
	}
	
	constants.push_back(Constant::getNullValue(Type::getInt8PtrTy(m.getContext())));
	
	return MakeTable(m, name, constants);
}

GlobalVariable* MakeTable(Module &m, StringRef name, vector<Constant*> values) {
	Constant *c = *values.begin();
	const Type *t = c->getType();
	const ArrayType *at = ArrayType::get(t, values.size());
	
	return new GlobalVariable(
		m,
		at,
		true,
		GlobalVariable::InternalLinkage,
		ConstantArray::get(at, values),
		name
	);
}

Function* MakeConstructor(Module &m, StringRef name) {
	// create constructor function
	Function *init = Function::Create(
		FunctionType::get(Type::getVoidTy(m.getContext()), false),
		Function::InternalLinkage,
		name,
		&m
	);
	
	// make a list of the libc constructors
	vector<Constant *> ctor_entry;
	ctor_entry.push_back(
		ConstantInt::get(
			IntegerType::getInt32Ty(m.getContext()),
			65535,
			false
		)
	);
	
	// add the randomizer runtime constructor to the list
	ctor_entry.push_back(init);
	
	vector<Constant *> ctor_data;
	ctor_data.push_back(ConstantStruct::get(m.getContext(), &ctor_entry[0], 2, false));
	
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
				ctor_data.push_back(entry);
			}
		}
	}
	
	// set up the constant initializer for the new constructor table
	Constant *ctor_array_const = ConstantArray::get(
		ArrayType::get(
			ctor_data[0]->getType(),
			ctor_data.size()
		),
		ctor_data
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
		ctors->uncheckedReplaceAllUsesWith(new_ctors);
		ctors->setLinkage(GlobalVariable::PrivateLinkage);
	} else {
		new_ctors->setName("llvm.global_ctors");
	}
	
	return init;
}

Function* getFloatConversion(Module &m, const Type *in, const Type *out, bool is_signed) {
	stringstream ss;

	if(in->isIntegerTy() && !out->isIntegerTy()) {
		if(!is_signed) {
			ss<<"uitofp";
		} else {
			ss<<"sitofp";
		}
	} else if(!in->isIntegerTy() && out->isIntegerTy()) {
		if(!is_signed) {
			ss<<"fptoui";
		} else {
			ss<<"fptosi";
		}
	} else {
		errs()<<"Invalid float conversion arguments\n";
		errs()<<"  in: "<<in->getDescription()<<"\n";
		errs()<<"  out: "<<out->getDescription()<<"\n";
		abort();
	}

	ss<<"."<<in->getDescription()<<"."<<out->getDescription();

	string name = ss.str();

	vector<const Type*> params;
	params.push_back(in);
	Function *f = m.getFunction(name);

	if(f == NULL) {
		f = Function::Create(FunctionType::get(out, params, false), Function::InternalLinkage, name, &m);
		f->addFnAttr(Attribute::NoInline);

		BasicBlock *b = BasicBlock::Create(m.getContext(), "", f);
		Instruction *r;

		if(is_signed && in->isIntegerTy()) {
			r = new SIToFPInst(&*f->arg_begin(), out, "", b);
		} else if(is_signed && out->isIntegerTy()) {
			r = new FPToSIInst(&*f->arg_begin(), out, "", b);
		} else if(!is_signed && in->isIntegerTy()) {
			r = new UIToFPInst(&*f->arg_begin(), out, "", b);
		} else {
			r = new FPToUIInst(&*f->arg_begin(), out, "", b);
		}

		ReturnInst::Create(m.getContext(), r, b);
	}

	return f;
}

set<Instruction*> Instructify(Value *v) {
	set<Instruction*> result;
	
	if(Instruction *i = dyn_cast<Instruction>(v)) {
		result.insert(i);
		
	} else if(Constant *c = dyn_cast<Constant>(v)) {
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
				
				if(ConstantExpr *e = dyn_cast<ConstantExpr>(v)) {
					vector<Value*> ops;
					for(int x=0; x<e->getNumOperands(); x++) {
						ops.push_back(e->getOperand(x));
					}
					
					Instruction *insertion_point = inst;
					if(PHINode *phi = dyn_cast<PHINode>(inst)) {
						insertion_point = phi->getIncomingBlock(*use)->getTerminator();
					}
					
					if(e->getOpcode() == Instruction::GetElementPtr) {
						instructified = GetElementPtrInst::Create(ops[0], ops.begin()+1, ops.end(), "", insertion_point);
						
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
	if(ConstantExpr *e = dyn_cast<ConstantExpr>(v)) {
		
		for(ConstantExpr::op_iterator op = e->op_begin(); op != e->op_end(); op++) {
			GlobifyFloats(m, op->get());
		}	
		
	} else if(ConstantFP *f = dyn_cast<ConstantFP>(v)) {
		Instructify(f);
		GlobalVariable *gv = new GlobalVariable(m, v->getType(), true, GlobalVariable::InternalLinkage, f, "fconst");
		
		vector<Use*> uses;
		for(Constant::use_iterator u = f->use_begin(); u != f->use_end(); u++) {
			uses.push_back(&u.getUse());
		}
		
		for(vector<Use*>::iterator use_iter = uses.begin(); use_iter != uses.end(); use_iter++) {
			Use *use = *use_iter;
			User *user = use->getUser();
				
			if(Instruction *i = dyn_cast<Instruction>(user)) {
				Instruction *insertion_point = i;
				
				if(PHINode *phi = dyn_cast<PHINode>(user)) {
					insertion_point = phi->getIncomingBlock(*use)->getTerminator();
				}
				
				LoadInst *load = new LoadInst(gv, "", insertion_point);
				use->set(load);
			}
		}
	}
}

Value* computeObjectSize(Module &m, const Type *t) {
	if(!t->isPointerTy()) {
		return computeObjectSize(m, PointerType::get(t, 0));
	}
	
	Constant *one = Constant::getIntegerValue(Type::getInt32Ty(m.getContext()), APInt(32, 1));

	return ConstantExpr::getPointerCast(
		ConstantExpr::getGetElementPtr(
			Constant::getNullValue(t),
			&one,
			1
		),
		Type::getInt64Ty(m.getContext())
	);	
}

size_t objectSize(const Type *t) {
	if(t->isPrimitiveType()) {
		return t->getPrimitiveSizeInBits()/8;
	}

	if(t->isIntegerTy() || t->isFloatTy()) {
		return t->getScalarSizeInBits()/8;
	}

	if(t->isPointerTy()) {
		return 8;
	}

	if(const ArrayType *a = dyn_cast<ArrayType>(t)) {
		return objectSize(a->getElementType()) * a->getNumElements();
	}

	if(const StructType *s = dyn_cast<StructType>(t)) {
		size_t total = 0;
		for(StructType::element_iterator e = s->element_begin(); e != s->element_end(); e++) {
			total += objectSize(e->get());
		}
		if(total % 16 != 0) {
			total += 16 - total % 16;
		}
		return total;
	}

	errs()<<"Unhandled object type: ";
	t->print(errs());
	errs()<<"\n";

	return 0;
}
