#define DEBUG_TYPE "stabilizer"

#include "llvm/Module.h"
#include "llvm/Function.h"
#include "llvm/Instructions.h"
#include "llvm/Constants.h"
#include "llvm/Type.h"
#include "llvm/DerivedTypes.h"
#include "llvm/Intrinsics.h"
#include "llvm/Pass.h"

#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/CommandLine.h"

#include "Util.h"
#include "StabilizedFunction.h"

#include <vector>
#include <map>
#include <iostream>

using namespace llvm;
using namespace std;

// Randomization configuration options
cl::opt<bool> stabilize_heap   ("stabilize-heap",    cl::init(false), cl::desc("Randomize heap object placement"));
cl::opt<bool> stabilize_globals("stabilize-globals", cl::init(false), cl::desc("Randomize global placement"));
cl::opt<bool> stabilize_stack  ("stabilize-stack",   cl::init(false), cl::desc("Randomize stack frame placement"));
cl::opt<bool> stabilize_code   ("stabilize-code",    cl::init(false), cl::desc("Randomize function placement"));

cl::opt<bool> enable_threads("stabilizer-enable-threads", cl::init(false), cl::desc("Enable multithreaded support"));

struct StabilizerPass : public ModulePass {
	static char ID;

	StabilizerPass() : ModulePass(ID) {}

	virtual bool runOnModule(Module &m) {
		/**
		 * Loop over all instruction operands in the module:
		 *   1. Scan for floating point constants
		 *   2. Convert floating point constants to global variables
		 *
		 * This ensures that floating point constants aren't placed in the constant pool, which is addressed with PC-relative modes
		 * TODO: Rewrite FP instructions to library calls if they add to the constant pool (uitofp, others)
		 */
        for(Function& f: m) {
            for(BasicBlock& b: f) {
                for(Instruction& i: b) {
					for(Instruction::op_iterator op = i.op_begin(); op != i.op_end(); op++) {
						GlobifyFloats(m, op->get());
					}
				}
			}
		}

		if(stabilize_heap) {
			Function *malloc_fn = m.getFunction("malloc");
			Function *calloc_fn = m.getFunction("calloc");
			Function *realloc_fn = m.getFunction("realloc");
			Function *free_fn = m.getFunction("free");

			if(malloc_fn) {
				Function *dh_malloc = Function::Create(
					 malloc_fn->getFunctionType(),
					 Function::ExternalLinkage,
					 "DH_malloc",
					 &m
				);

				malloc_fn->replaceAllUsesWith(dh_malloc);
			}

			if(calloc_fn) {
				Function *dh_calloc = Function::Create(
					 calloc_fn->getFunctionType(),
					 Function::ExternalLinkage,
					 "DH_calloc",
					 &m
				);

				calloc_fn->replaceAllUsesWith(dh_calloc);
			}

			if(realloc_fn) {
				Function *dh_realloc = Function::Create(
					 realloc_fn->getFunctionType(),
					 Function::ExternalLinkage,
					 "DH_realloc",
					 &m
				);

				realloc_fn->replaceAllUsesWith(dh_realloc);
			}

			if(free_fn) {
				Function *dh_free = Function::Create(
					 free_fn->getFunctionType(),
					 Function::ExternalLinkage,
					 "DH_free",
					 &m
				);

				free_fn->replaceAllUsesWith(dh_free);
			}
		}

		if(stabilize_stack) {
			vector<Type*> params;
			params.push_back(Type::getInt8PtrTy(m.getContext(), 0));
			params.push_back(Type::getInt64Ty(m.getContext()));

			Function::Create(
				FunctionType::get(Type::getInt8PtrTy(m.getContext(), 0), ArrayRef<Type*>(params), false),
				Function::ExternalLinkage,
				"stabilizer_relocate_frame",
				&m
			);
		}

		/**
		 * For all non-intrinsic functions in the module:
		 *   1. Convert all references to the function into instructions (ConstantExprs become Instructions)
		 *   2. Add to the functions set
		 *
		 * This makes it possible to replace function references with values loaded from functions' indirection tables
		 */
		set<Function*> functions;
		for(Module::iterator f = m.begin(); f != m.end(); f++) {
			if(!f->isIntrinsic()) {
				if(!f->getName().equals("__gxx_personality_v0")) {
					Instructify(&*f);
				}

				functions.insert(&*f);
			}
		}

		set<Function*> stabilized_functions;
		for(set<Function*>::iterator f_iter = functions.begin(); f_iter != functions.end(); f_iter++) {
			Function *f = *f_iter;

			if(!f->isDeclaration() && !f->isIntrinsic()) {
				stabilized_functions.insert(&*f);
			}
		}

		if(stabilize_stack) {
			for(set<Function*>::iterator f_iter = stabilized_functions.begin(); f_iter != stabilized_functions.end(); f_iter++) {
				Function *f = *f_iter;
				if(!f->isIntrinsic() && !f->isDeclaration()) {
					GlobalVariable *depth = new GlobalVariable(
						m, 
						Type::getInt32Ty(m.getContext()), 
						false, 
						GlobalVariable::InternalLinkage, 
						ConstantInt::get(
							Type::getInt32Ty(m.getContext()), 
							0, 
							false
						), 
						"stabilizer.depth."+f->getName(), 
						NULL, 
						enable_threads
					);
					
					GlobalVariable *frame_table = makeFrameTable(m, &*f);
					randomizeStack(m, &*f, depth, frame_table);
				}
			}
		}

		// Add a module constructor
		Function *ctor = MakeConstructor(m, "stabilizer.module_ctor");
		BasicBlock *ctor_bb = BasicBlock::Create(m.getContext(), "", ctor);

		if(stabilize_code) {
			/**
			 * For all defined functions in the module:
			 *   1. Disable stack smashing protection
			 *   2. Remove linkonce_odr linkage
			 *   3. Increment the users counter on entry, decrement on exit
			 *   4. Add to the randomized functions set
			 *
			 * Stack smashing protection results in PC-relative addressing.
			 *
			 * The linkonce_odr option moves the function elsewhere in the module, so the dummy function placed after it
			 * is no longer the next function.
			 *
			 * TODO: Re-implement stack smashing protection using the indirection table
			 * TODO: Check if adding linkonce_odr to the dummy is good enough.
			 */
			for(Function* f: stabilized_functions) {
				if(f->getAlignment() < ALIGN) {
					f->setAlignment(ALIGN);
				}

				f->removeFnAttr(Attribute::StackProtect);
				f->removeFnAttr(Attribute::StackProtectReq);

				if(f->getLinkage() == GlobalValue::LinkOnceODRLinkage) {
					f->setLinkage(GlobalValue::ExternalLinkage);
				}

				StabilizedFunction::get(f)->trackUsers();
			}

			/**
			 * For all randomized functions
			 *   For all basic blocks
			 *     For all instructions
			 *       If instruction is a uitofp, sitofp, fptoui or fptosi:
			 *         1. Get an equivalent function
			 *         2. Replace the instruction with a call to the function
			 *
			 * The floating point conversion instructions create implicit constants in the constant pool,
			 * which makes it impossible to relocate the function at runtime.
			 */
            for(Function* f: stabilized_functions) {
				vector<Instruction*> to_delete;
                for(BasicBlock& b: *f) {
                    for(Instruction& i: b) {
						if(dyn_cast<FPToSIInst>(&i) || dyn_cast<SIToFPInst>(&i)) {
							Function *f = getFloatConversion(m, i.getOperand(0)->getType(), i.getType(), true);
							functions.insert(f);

							vector<Value*> args;
							args.push_back(i.getOperand(0));
							CallInst *ci = CallInst::Create(f, ArrayRef<Value*>(args), "", &i);

							i.replaceAllUsesWith(ci);
							to_delete.push_back(&i);

						} else if(dyn_cast<FPToUIInst>(&i) || dyn_cast<UIToFPInst>(&i)) {
							Function *f = getFloatConversion(m, i.getOperand(0)->getType(), i.getType(), false);
							functions.insert(f);

							vector<Value*> args;
							args.push_back(i.getOperand(0));
							CallInst *ci = CallInst::Create(f, ArrayRef<Value*>(args), "", &i);

							i.replaceAllUsesWith(ci);
							to_delete.push_back(&i);
						}
					}
				}

                for(Instruction* i: to_delete) {
					i->eraseFromParent();
				}
			}

			/**
			 * For all globals in the module:
			 *   1. Convert all references into instructions
			 *   2. Add to the globals set
			 *
			 * This makes it possible to replace references with values from functions' indirection tables
			 */
			set<GlobalVariable*> globals;
			for(Module::global_iterator g = m.global_begin(); g != m.global_end(); g++) {
				if(!g->getName().equals("llvm.eh.catch.all.value")) {
					Instructify(&*g);
					globals.insert(&*g);
				}
			}

			/**
			 * For all non-intrinsic functions in the module:
			 *   1. For all use sites:
			 *     a. Convert the use site to one through the user function's indirection table (if user is randomized)
			 *     b. If the user is not an Instruction, show a warning
			 */
			for(Function* f: functions) {

				vector<Use*> uses;
				for(Function::use_iterator u = f->use_begin(); u != f->use_end(); u++) {
					Use &use = u.getUse();
					uses.push_back(&use);
				}

                for(Use* use: uses) {
					User *user = use->getUser();

					Instruction *i = dyn_cast<Instruction>(user);
					if(i != NULL && stabilized_functions.find(i->getParent()->getParent()) != stabilized_functions.end()) {
						StabilizedFunction *s = StabilizedFunction::get(i->getParent()->getParent());
						s->makeUseLocal(*use);
					}
				}
			}

			set<GlobalVariable*> randomized_globals;

			/**
			 * For all globals in the module:
			 *   1. For all use sites:
			 *     a. Convert the use site to one through the user function's indirection table
			 *     b. If the user is not an Instruction, show a warning
			 */
			for(set<GlobalVariable*>::iterator g_iter = globals.begin(); g_iter != globals.end(); g_iter++) {
				GlobalVariable *g = *g_iter;

				vector<Use*> uses;
				for(GlobalVariable::use_iterator u = g->use_begin(); u != g->use_end(); u++) {
					Use &use = u.getUse();
					uses.push_back(&use);
				}

				bool always_random = true;

				for(vector<Use*>::iterator u = uses.begin(); u != uses.end(); u++) {
					Use *use = *u;
					User *user = use->getUser();

					Instruction *i = dyn_cast<Instruction>(user);
					if(i != NULL) {
						if(stabilized_functions.find(i->getParent()->getParent()) != stabilized_functions.end()) {
							StabilizedFunction *s = StabilizedFunction::get(i->getParent()->getParent());
							s->makeUseLocal(*use);
						} else {
							always_random = false;
						}
					} else {
						always_random = false;
					}
				}

				if(always_random) {
					randomized_globals.insert(g);
				}
			}
			
			// Declare the register_function runtime function
			vector<Type*> register_global_params;
			register_global_params.push_back(Type::getInt8PtrTy(m.getContext(), 0));
			register_global_params.push_back(Type::getInt64Ty(m.getContext()));

			Function *register_g = Function::Create(
				 FunctionType::get(Type::getVoidTy(m.getContext()), ArrayRef<Type*>(register_global_params), false),
				 Function::ExternalLinkage,
				 "stabilizer_register_global",
				 &m
			);

			if(stabilize_globals) {
				for(set<GlobalVariable*>::iterator g_iter = randomized_globals.begin(); g_iter != randomized_globals.end(); g_iter++) {
					GlobalVariable *g = *g_iter;

					if(!g->getName().equals("llvm.global_ctors") && !g->getName().equals("llvm.used") && !g->isConstant()) {
						vector<Value*> args;
						args.push_back(BitCastInst::CreatePointerCast(g, Type::getInt8PtrTy(m.getContext(), 0), "", ctor_bb));
						args.push_back(ConstantExpr::getSizeOf(g->getType()->getElementType()));

						CallInst::Create(register_g, ArrayRef<Value*>(args), "", ctor_bb);
					} else {
						//errs()<<"skipping global "<<g->getNameStr()<<"\n";
					}
				}
			}

			// Declare the register_function runtime function
			vector<Type*> params;
			params.push_back(PointerType::get(StabilizedFunction::getInfoType(m), 0));

			Function *register_fn = Function::Create(
				 FunctionType::get(Type::getVoidTy(m.getContext()), ArrayRef<Type*>(params), false),
				 Function::ExternalLinkage,
				 "stabilizer_register_function",
				 &m
			);
			
			/**
			 * For all non-intrinsic functions in the module:
			 *   1. Call stabilizer_register_function
			 */
			for(set<Function*>::iterator f_iter = stabilized_functions.begin(); f_iter != stabilized_functions.end(); f_iter++) {
				Function *f = *f_iter;
				
				if(!f->isDeclaration()) {
					StabilizedFunction *s = StabilizedFunction::get(f);

					vector<Value*> args;
					args.push_back(s->getInfo());

					CallInst::Create(register_fn, ArrayRef<Value*>(args), "", ctor_bb);
				}
			}
		}
		
		ReturnInst::Create(m.getContext(), ctor_bb);
		
		Function *main = m.getFunction("main");
		if(main != NULL) {
			main->setName("stabilizer_main");
		}

		return true;
	}

	GlobalVariable* makeFrameTable(Module &m, Function *f, size_t num_frames = 256) {
		vector<Constant*> vals;

		StabilizedFunction *s = StabilizedFunction::get(f);

		PointerType *locals_type = PointerType::get(s->getRandomAllocaStructType(), 0);
		StructType *entry_type = StructType::get(locals_type, locals_type, NULL);

		for(size_t i=0; i<num_frames; i++) {
			vector<Constant*> entry_vals;
			entry_vals.push_back(Constant::getNullValue(locals_type));
			entry_vals.push_back(Constant::getNullValue(locals_type));

			vals.push_back(ConstantStruct::get(
				entry_type,
				Constant::getNullValue(locals_type),
				Constant::getNullValue(locals_type),
				NULL
			));
		}

		return new GlobalVariable(
			m,
			ArrayType::get(entry_type, num_frames),
			false,
			GlobalVariable::InternalLinkage,
			ConstantArray::get(ArrayType::get(entry_type, num_frames), vals),
			"stabilizer.frames."+f->getName(),
			NULL,
			enable_threads
		);
	}

	void randomizeStack(Module &m, Function *f, GlobalVariable *depth_global, GlobalVariable *frame_table_global) {
		StabilizedFunction *s = StabilizedFunction::get(f);

		if(!s->hasRandomAllocas()) {
			return;
		}

		BasicBlock *old_entry = &f->getEntryBlock();

		// Create basic blocks for frame allocation
		BasicBlock *new_entry = BasicBlock::Create(m.getContext(), "new_entry", &*f, old_entry);	// Load the cached frame address
		BasicBlock *get_frame = BasicBlock::Create(m.getContext(), "get_frame", &*f, old_entry);	// Free an old frame
		BasicBlock *set_stack = BasicBlock::Create(m.getContext(), "set_stack", &*f, old_entry);	// Set the stack pointer

		// Load and increment the current depth
		Instruction *depth = new LoadInst(depth_global, "depth", new_entry);

		BinaryOperator *new_depth = BinaryOperator::CreateNUWAdd(
			depth,
			ConstantInt::get(Type::getInt32Ty(m.getContext()), 1, false),
			"new_depth",
			new_entry
		);

		new StoreInst(new_depth, depth_global, new_entry);

		// Get a pointer to the frame entry
		vector<Value*> indices;
		indices.push_back(Constant::getIntegerValue(Type::getInt32Ty(m.getContext()), APInt(32, 0, false)));
		indices.push_back(depth);
		indices.push_back(Constant::getIntegerValue(Type::getInt32Ty(m.getContext()), APInt(32, 0, false)));

		GetElementPtrInst *frame_p = GetElementPtrInst::Create(
			frame_table_global,
			ArrayRef<Value*>(indices),
			"frame_p",
			new_entry
		);

		LoadInst *frame = new LoadInst(frame_p, "frame", new_entry);
		CastInst *frame_int = CastInst::CreatePointerCast(frame, Type::getInt64Ty(m.getContext()), "frame_int", new_entry);

		ICmpInst *null_frame = new ICmpInst(
			*new_entry,
			ICmpInst::ICMP_EQ,
			ConstantInt::getIntegerValue(Type::getInt64Ty(m.getContext()), APInt(64, 0, false)),
			frame_int,
			"null_frame"
		);

		BranchInst::Create(get_frame, set_stack, null_frame, new_entry);

		// Cast the address of the frame table entry to an i8p
		CastInst *frame_p_i8p = BitCastInst::CreatePointerCast(frame_p, Type::getInt8PtrTy(m.getContext(), 0), "", get_frame);

		// get a new frame, set it, and resume normal execution
		vector<Value*> relocate_frame_args;
		relocate_frame_args.push_back(frame_p_i8p);
		relocate_frame_args.push_back(ConstantExpr::getSizeOf(s->getRandomAllocaStructType()));

		CallInst *new_frame_i8p = CallInst::Create(
			m.getFunction("stabilizer_relocate_frame"),
			ArrayRef<Value*>(relocate_frame_args),
			"",
			get_frame
		);

		CastInst *new_frame = BitCastInst::CreatePointerCast(
			new_frame_i8p,
			PointerType::get(s->getRandomAllocaStructType(), 0),
			"",
			get_frame
		);

		// Unconditionally branch to the pad stack block
		BranchInst::Create(set_stack, get_frame);

		// set the previously allocated frame
		PHINode *frame_struct = PHINode::Create(PointerType::get(s->getRandomAllocaStructType(), 0), 0, "", set_stack);

		frame_struct->addIncoming(frame, new_entry);
		frame_struct->addIncoming(new_frame, get_frame);

		// Unconditionally branch to the original entry block for now
		BranchInst::Create(old_entry, set_stack);

		// decrement the depth counter before returning
		for(Function::iterator b = f->begin(); b != f->end(); b++) {
			vector<Instruction*> replaced;

			for(BasicBlock::iterator i = b->begin(); i != b->end(); i++) {
				if(s->isRandomAlloca(&*i)) {
					vector<Value*> local_indices;
					local_indices.push_back(Constant::getIntegerValue(Type::getInt32Ty(m.getContext()), APInt(32, 0, false)));
					local_indices.push_back(Constant::getIntegerValue(Type::getInt32Ty(m.getContext()), APInt(32, s->getRandomAllocaStructIndex(&*i), false)));

					GetElementPtrInst *new_local = GetElementPtrInst::Create(
						frame_struct,
						ArrayRef<Value*>(local_indices),
						"randomized_"+i->getName(),
						&*i
					);
					
					if(i->getType() == new_local->getType()) {
						i->replaceAllUsesWith(new_local);
						replaced.push_back(&*i);
					} else {
						errs() << "Type mismatch for local replacement of " << i->getName() << "\n";
						errs() << "  Replacing ";
						i->getType()->print(errs());
						errs() << " with ";
						new_local->getType()->print(errs());
						errs() << "\n";
					}
				}
			}

			for(vector<Instruction*>::iterator i_iter = replaced.begin(); i_iter != replaced.end(); i_iter++) {
				Instruction *i = *i_iter;
				// Why does this break GCC?
				i->eraseFromParent();
			}

			ReturnInst *r = dyn_cast<ReturnInst>(b->getTerminator());
			if(r != NULL) {
				Instruction *end_depth = new LoadInst(depth_global, "depth", r);
				BinaryOperator *restore_depth = BinaryOperator::CreateNUWSub(end_depth, ConstantInt::get(Type::getInt32Ty(m.getContext()), 1, false), "restore_depth", r);
				new StoreInst(restore_depth, depth_global, r);
			}
		}
	}
};

char StabilizerPass::ID = 0;
static RegisterPass<StabilizerPass> X("stabilize", "Add support for runtime randomization of program layout");
