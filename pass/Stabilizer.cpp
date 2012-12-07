#define DEBUG_TYPE "stabilizer"

#include <llvm/Pass.h>
#include <llvm/Module.h>
#include <llvm/Constants.h>
#include <llvm/Intrinsics.h>
#include <llvm/Instructions.h>

#include <llvm/Support/raw_ostream.h>
#include <llvm/Support/CommandLine.h>
#include <llvm/Support/TypeBuilder.h>

#include <map>
#include <set>
#include <vector>
#include <llvm/Intrinsics.gen>

using namespace llvm;
using namespace llvm::types;
using namespace llvm::cl;

using namespace std;

enum { ALIGN = 64 };

// Randomization configuration options
opt<bool> stabilize_heap   ("stabilize-heap",    init(false), desc("Randomize heap object placement"));
opt<bool> stabilize_globals("stabilize-globals", init(false), desc("Randomize global placement"));
opt<bool> stabilize_stack  ("stabilize-stack",   init(false), desc("Randomize stack frame placement"));
opt<bool> stabilize_code   ("stabilize-code",    init(false), desc("Randomize function placement"));

struct StabilizerPass : public ModulePass {
	static char ID;

	Function* registerFunction;
	Function* registerConstructor;
	Function* stackPadding;
	
	StabilizerPass() : ModulePass(ID) {}

	enum Platform {
		x86_64,
		x86_32,
		PowerPC,
		INVALID
	};
	
	/**
	 * \brief Get the architecture targeted by a given module
	 * \arg m The module being transformed
	 * \returns A Platform value
	 */
	Platform getPlatform(Module& m) {
		string triple = m.getTargetTriple();
		
		// Convert the target-triple to lowercase using C++'s elegant, intuitive API
		transform(triple.begin(), triple.end(), triple.begin(), ::tolower);
		
		if(triple.find("x86_64") != string::npos
			|| triple.find("amd64") != string::npos) {
			return x86_64;
			
		} else if(triple.find("i386") != string::npos
			|| triple.find("i486") != string::npos
			|| triple.find("i586") != string::npos
			|| triple.find("i686") != string::npos) {
			return x86_32;
			
		} else if(triple.find("powerpc") != string::npos) {
			return PowerPC;
			
		} else {
			return INVALID;
		}
	}
	
	/**
	 * \brief Check if the target platform uses PC-relative addressing for data
	 * \arg m The module being transformed
	 * \returns true if the platform supports PC-relative data addressing modes
	 */
	bool isDataPCRelative(Module& m) {
		switch(getPlatform(m)) {
			case x86_64:
				return true;
				
			case x86_32:
			case PowerPC:
				return false;
				
			default:
				return true;
		}
	}
	
	/**
	 * \brief Entry point for the Stabilizer compiler pass
	 * \arg m The module being transformed
	 * \returns whether or not the module was modified (always true)
	 */
	virtual bool runOnModule(Module &m) {
		// Replace calls to heap functions with Stabilizer's random heap
		if(stabilize_heap) {
			randomizeHeap(m);
		}

		// Build a set of locally-defined functions
		set<Function*> local_functions;
		for(Module::iterator f = m.begin(); f != m.end(); f++) {
			if(!f->isIntrinsic() 
				&& !f->isDeclaration() 
				&& !f->getName().equals("__gxx_personality_v0")) {
				
				local_functions.insert(&*f);
			}
		}
		
		declareRuntimeFunctions(m);

		// Enable stack randomization
		if(stabilize_stack) {
			// Transform each function
			for(set<Function*>::iterator f_iter = local_functions.begin();
			f_iter != local_functions.end(); f_iter++) {
				
				randomizeStack(m, **f_iter);
			}
		}

		// Get any existing module constructors
		vector<Value*> old_ctors = getConstructors(m);
		
		// Create a new constructor
		Function* ctor = makeConstructor(m, "stabilizer.module_ctor");
		BasicBlock* ctor_bb = BasicBlock::Create(m.getContext(), "", ctor);

		// Enable code randomization
		if(stabilize_code) {
			// Transform each function and register it with the stabilizer runtime
			for(set<Function*>::iterator f_iter = local_functions.begin();
				f_iter != local_functions.end(); f_iter++) {
				
				Function* f = *f_iter;
				vector<Value*> args = randomizeCode(m, *f);
				CallInst::Create(registerFunction, args, "", ctor_bb);
			}
		}
		
		// Register each existing constructor with the stabilizer runtime
		for(vector<Value*>::iterator ctor_iter = old_ctors.begin(); ctor_iter != old_ctors.end(); ctor_iter++) {
			vector<Value*> args;
			args.push_back(*ctor_iter);
			CallInst::Create(registerConstructor, args, "", ctor_bb);
		}
		
		ReturnInst::Create(m.getContext(), ctor_bb);
		
		Function *main = m.getFunction("main");
		if(main != NULL) {
			main->setName("stabilizer_main");
		}

		return true;
	}
	
	/**
	 * \brief Get a list of module constructors
	 * \arg m The module to scan
	 */
	vector<Value*> getConstructors(Module& m) {
		vector<Value*> result;
		
		// Get the constructor table
		GlobalVariable *ctors = m.getGlobalVariable("llvm.global_ctors", false);
		
		// If not found, there aren't any constructors
		if(ctors != NULL) {
			// Get the constructor table initializer
			ConstantArray* table = dyn_cast<ConstantArray>(ctors->getInitializer());

			// Get each entry in the table
			for(ConstantArray::op_iterator i = table->op_begin(); i != table->op_end(); i++) {
				ConstantStruct* entry = dyn_cast<ConstantStruct>(i->get());
				Constant* f = entry->getOperand(1);
				result.push_back(f);
			}
		}
		
		return result;
	}
	
	/**
	 * \brief Create a single module constructor
	 * Replaces any existing constructors
	 * \arg m The module to add a constructor to
	 * \arg name The name of the new constructor function
	 * \returns The new constructor function
	 */
	Function* makeConstructor(Module& m, StringRef name) {
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
		Function* init = Function::Create(ctor_fn_t, Function::InternalLinkage, name, &m);

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

		// Get the existing constructor array from the module, if any
		GlobalVariable *ctors = m.getGlobalVariable("llvm.global_ctors", false);
		
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
	
	/**
	 * \brief Randomize the program stack on each function call
	 * Adds a random pad (obtained from the Stabilizer runtime) to the stack
	 * pointer prior to each function call, then restores the stack after the call.
	 * 
	 * \arg m The module being transformed
	 * \arg f The function being transformed
	 */
	void randomizeStack(Module& m, llvm::Function& f) {
		Function* stacksave = Intrinsic::getDeclaration(&m, Intrinsic::stacksave);
		Function* stackrestore = Intrinsic::getDeclaration(&m, Intrinsic::stackrestore);
		
		vector<CallInst*> calls;
		
		for(Function::iterator b_iter = f.begin(); b_iter != f.end(); b_iter++) {
			BasicBlock& b = *b_iter;
			
			for(BasicBlock::iterator i_iter = b.begin(); i_iter != b.end(); i_iter++) {
				Instruction& i = *i_iter;
				
				if(isa<CallInst>(&i)) {
					CallInst* c = dyn_cast<CallInst>(&i);
					calls.push_back(c);
				}
			}
		}
		
		for(vector<CallInst*>::iterator c_iter = calls.begin(); c_iter != calls.end(); c_iter++) {
			CallInst* c = *c_iter;
			Instruction* next = c->getNextNode();
			
			CallInst* oldStack = CallInst::Create(stacksave, "", c);
			PtrToIntInst* oldStackInt = new PtrToIntInst(oldStack, Type::getInt64Ty(m.getContext()), "", c);

			CallInst* padSize = CallInst::Create(stackPadding, "", c);

			BinaryOperator* newStackInt = BinaryOperator::CreateSub(oldStackInt, padSize, "", c);
			IntToPtrInst* newStack = new IntToPtrInst(newStackInt, Type::getInt8PtrTy(m.getContext()), "", c);

			vector<Value*> newStackArgs;
			newStackArgs.push_back(newStack);
			CallInst::Create(stackrestore, newStackArgs, "", c);

			vector<Value*> oldStackArgs;
			oldStackArgs.push_back(oldStack);
			CallInst::Create(stackrestore, oldStackArgs, "", next);
		}
	}
	
	/**
	 * \brief Transform a function to reference globals only through a relocation table.
	 * 
	 * \arg m The module being transformed
	 * \arg f The function being transformed
	 * \returns The arguments to be passed to stabilizer_register_function
	 */
	vector<Value*> randomizeCode(Module& m, Function& f) {
		// Add a dummy function used to compute the size
		Function* next = Function::Create(
			FunctionType::get(Type::getVoidTy(m.getContext()), false),
			GlobalValue::InternalLinkage,
			"stabilizer.dummy."+f.getName()
		);
		
		// Align the following function to a cache line to avoid mixing code/data in cache
		next->setAlignment(ALIGN);
		
		// Put a basic block and return instruction into the dummy function
		BasicBlock *dummy_block = BasicBlock::Create(m.getContext(), "", next);
		ReturnInst::Create(m.getContext(), dummy_block);

		// Ensure the dummy is placed immediately after our function
		if(f.getNextNode() == NULL) {
			m.getFunctionList().setNext(&f, next);
			m.getFunctionList().addNodeToList(next);
		} else {
			m.getFunctionList().setNext(next, f.getNextNode());
			m.getFunctionList().setNext(&f, next);
			m.getFunctionList().addNodeToList(next);
		}
		
		// Remove stack protection (creates implicit global references)
		f.removeFnAttr(Attribute::StackProtect);
		f.removeFnAttr(Attribute::StackProtectReq);
		
		// Remove linkonce_odr linkage
		if(f.getLinkage() == GlobalValue::LinkOnceODRLinkage) {
			f.setLinkage(GlobalValue::ExternalLinkage);
		}
		
		// Replace some floating point operations with calls to un-randomized functions
		if(isDataPCRelative(m)) {
			extractFloatOperations(f);
		}
		
		// Collect all the referenced global values in this function
		map<Constant*, set<Use*> > references = findPCRelativeUses(f);
		
		if(references.size() > 0) {
			// Build an ordered list of referenced constants
			vector<Constant*> referencedValues;
			for(map<Constant*, set<Use*> >::iterator p_iter = references.begin();
				p_iter != references.end(); p_iter++) {
				
				pair<Constant*, set<Use*> > p = *p_iter;
				referencedValues.push_back(p.first);
			}
			
			// Create an ordered list of types for the referenced constants
			vector<Type*> referencedTypes;
			for(vector<Constant*>::iterator c_iter = referencedValues.begin();
				c_iter != referencedValues.end(); c_iter++) {
				
				Constant* c = *c_iter;
				referencedTypes.push_back(c->getType());
			}

			// Create the struct type for the relocation table
			StructType* relocationTableType = StructType::create(
				referencedTypes, 
				(f.getName()+".relocation_table_t").str(), 
				false
			);
			
			// Create the relocation table global variable
			GlobalVariable* relocationTable = new GlobalVariable(
				m, 
				relocationTableType, 
				true,	// Yes, the table is constant
				GlobalVariable::InternalLinkage, 
				ConstantStruct::get(relocationTableType, referencedValues),
				f.getName()+".relocation_table"
			);
			
			// The referenced relocation table may not be the global one (for PC-relative data)
			Constant* actualRelocationTable = relocationTable;
			
			// Cast next-function pointer to the relocation table type for PC-relative data
			if(isDataPCRelative(m)) {
				Type* ptr = PointerType::get(relocationTableType, 0);
				actualRelocationTable = ConstantExpr::getPointerCast(next, ptr);
			}
			
			// Rewrite global references to use the relocation table
			size_t index = 0;
			for(vector<Constant*>::iterator c_iter = referencedValues.begin(); c_iter != referencedValues.end(); c_iter++) {
				Constant* c = *c_iter;
				
				for(set<Use*>::iterator u_iter = references[c].begin();
					u_iter != references[c].end(); u_iter++) {
					
					Use* u = *u_iter;
					
					Instruction* insertion_point = dyn_cast<Instruction>(u->getUser());
					assert(insertion_point != NULL && "Only instruction uses can be rewritten");
					
					if(isa<PHINode>(insertion_point)) {
						PHINode* phi = dyn_cast<PHINode>(insertion_point);
						BasicBlock *incoming = phi->getIncomingBlock(*u);
						insertion_point = incoming->getTerminator();
					}
					
					// Get the relocation table slot
					vector<Constant*> indices;
					indices.push_back(Constant::getIntegerValue(Type::getInt32Ty(m.getContext()), APInt(32, 0, false)));
					indices.push_back(Constant::getIntegerValue(Type::getInt32Ty(m.getContext()), APInt(32, (uint64_t)index, false)));
					
					Constant* slot = ConstantExpr::getGetElementPtr(
						actualRelocationTable,
						indices,
						true	// Yes, it is in bounds
					);
					
					Value* loaded = new LoadInst(
						slot, 
						c->getName()+".indirect", 
						insertion_point
					);
					
					if(isa<PHINode>(u->getUser())) {
						PHINode* phi = dyn_cast<PHINode>(u->getUser());
						BasicBlock* incoming = phi->getIncomingBlock(*u);
						while(phi->getBasicBlockIndex(incoming) != -1) {
							phi->removeIncomingValue(incoming, false);
						}
						phi->addIncoming(loaded, incoming);
						
					} else {
						u->set(loaded);
					}
				}
				
				index++;
			}
			
			vector<Value*> args;
		
			// The function base
			args.push_back(ConstantExpr::getPointerCast(&f, Type::getInt8PtrTy(m.getContext())));

			// The function limit
			args.push_back(ConstantExpr::getPointerCast(next, Type::getInt8PtrTy(m.getContext())));

			// The global relocation table
			args.push_back(ConstantExpr::getPointerCast(relocationTable, Type::getInt8PtrTy(m.getContext())));
			
			// The size of the relocation table
			args.push_back(ConstantExpr::getIntegerCast(ConstantExpr::getSizeOf(relocationTableType), Type::getInt32Ty(m.getContext()), false));
			
			// If true, the function uses an adjacent relocation table, not the global
			args.push_back(Constant::getIntegerValue(Type::getInt1Ty(m.getContext()), APInt(1, isDataPCRelative(m), false)));
		
			return args;
			
		} else {
			vector<Value*> args;
			
			// The function base
			args.push_back(ConstantExpr::getPointerCast(&f, Type::getInt8PtrTy(m.getContext())));
			
			// The function limit
			args.push_back(ConstantExpr::getPointerCast(next, Type::getInt8PtrTy(m.getContext())));
			
			// The global relocation table (null)
			args.push_back(Constant::getNullValue(Type::getInt8PtrTy(m.getContext())));
			
			// The size of the relocation table (0)
			args.push_back(Constant::getIntegerValue(Type::getInt32Ty(m.getContext()), APInt(32, 0, false)));
			
			// PC-relative data?  Doesn't matter
			args.push_back(Constant::getIntegerValue(Type::getInt1Ty(m.getContext()), APInt(1, 0, false)));
			
			return args;
		}
	}
	
	/**
	 * \brief Check if a use occurs inside a function
	 * \arg use The use to check
	 * \arg f The function we're looking in
	 * \returns true if the use or any of its ancestors is an instruction in f
	 */
	bool isUseInFunction(Use& use, Function& f) {
		User* user = use.getUser();
		
		if(isa<Instruction>(user)) {
			Instruction* i = dyn_cast<Instruction>(user);
			return i->getParent() != NULL && i->getParent()->getParent() == &f;
			
		} else {
			for(Value::use_iterator iter = user->use_begin(); iter != user->use_end(); iter++) {
				if(isUseInFunction(iter.getUse(), f)) {
					return true;
				}
			}
			
			return false;
		}
	}
	
	/**
	 * \brief Given a use, climb the hierarchy of uses until an instruction is reached.
	 * 
	 * When instruction I uses constexpr E, which uses global G:
	 *  Given E's use of G, returns I's use of E.
	 * 
	 * \arg u The use of some global value
	 * \returns The lowest-possible set of u's ancestor uses s.t. all users are Instructions
	 */
	set<Use*> findInstructionUses(Use* u) {
		User* user = u->getUser();
		
		set<Use*> lifted;
		
		if(isa<Instruction>(user)) {
			// If the user is an instruction, we're done!
			lifted.insert(u);
			
		} else {
			// If not, get instruction uses of the user (recursively)
			for(Value::use_iterator iter = user->use_begin(); iter != user->use_end(); iter++) {
				Use* use_of_user = &iter.getUse();
				set<Use*> lus = findInstructionUses(use_of_user);
				
				for(set<Use*>::iterator lu_iter = lus.begin();
					lu_iter != lus.end(); lu_iter++) {
					
					lifted.insert(*lu_iter);
				}
			}
		}
		
		return lifted;
	}
	
	/**
	 * \brief Find all uses inside instructions that may result in PC-relative addressing.
	 * 
	 * \arg f The function to scan for PC-relative uses
	 * \returns A map of all used values, each with a set of uses
	 */
	map<Constant*, set<Use*> > findPCRelativeUses(Function& f) {
		Module& m = *f.getParent();
		set<GlobalValue*> gvs;
		
		// Functions are always possible to access with pc-relative instructions
		for(Module::iterator g_iter = m.begin(); g_iter != m.end(); g_iter++) {
			Function& g = *g_iter;
			if(!g.isIntrinsic()) {
				gvs.insert(&g);
			}
		}
		
		// If the platform support pc-relative data accesses, include global variables too
		if(isDataPCRelative(m)) {
			for(Module::global_iterator iter = m.global_begin(); iter != m.global_end(); iter++) {
				gvs.insert(&*iter);
			}
		}
		
		// Get all uses of all global values
		set<Use*> uses;
		for(set<GlobalValue*>::iterator gv_iter = gvs.begin(); gv_iter != gvs.end(); gv_iter++) {
			GlobalValue* gv = *gv_iter;
			
			for(Value::use_iterator iter = gv->use_begin(); iter != gv->use_end(); iter++) {
				Use* use = &iter.getUse();
				
				// If the use is in the function we're working on now
				if(isUseInFunction(*use, f)) {
					
					// If the use is inside a constant expression, get the uses
					// of the constant expression, recursively
					set<Use*> lus = findInstructionUses(use);
					for(set<Use*>::iterator lu_iter = lus.begin();
						lu_iter != lus.end(); lu_iter++) {
						
						if(isUseInFunction(**lu_iter, f)) {
							uses.insert(*lu_iter);
						}
					}
				}
			}
		}

		map<Constant*, set<Use*> > references;
		
		for(set<Use*>::iterator use_iter = uses.begin(); use_iter != uses.end(); use_iter++) {
			Use* use = *use_iter;
			Value* v = use->get();
			Constant* c = dyn_cast<Constant>(v);
			
			assert(c != NULL);
			
			if(references.find(c) == references.end()) {
				references[c] = set<Use*>();
			}
			references[c].insert(use);
		}
		
		return references;
	}
	
	/**
	 * \brief Replace certain floating point operations with function calls.
	 * Some floating point operations (definitely int-to-float and float-to-int)
	 * create implicit references to floating point constants.  Replace these
	 * with function calls so they don't produce PC-relative data references in
	 * randomizable code.
	 * 
	 * \arg f The function to scan for floating point operations
	 */
	void extractFloatOperations(Function& f) {
		Module& m = *f.getParent();
		vector<Instruction*> to_delete;
		for(Function::iterator b_iter = f.begin(); b_iter != f.end(); b_iter++) {
			BasicBlock& b = *b_iter;
			for(BasicBlock::iterator i_iter = b.begin(); i_iter != b.end(); i_iter++) {
				Instruction& i = *i_iter;
				
				if(isa<FPToSIInst>(&i)
					|| isa<FPToUIInst>(&i)
					|| isa<SIToFPInst>(&i)
					|| isa<UIToFPInst>(&i)
					|| (isa<FPTruncInst>(&i) && getPlatform(m) == PowerPC)) {
					
					Function* f = getFloatConversion(m, i.getOpcode(), i.getOperand(0)->getType(), i.getType());
					
					vector<Value*> args;
					args.push_back(i.getOperand(0));
					CallInst *ci = CallInst::Create(f, ArrayRef<Value*>(args), "", &i);
					
					i.replaceAllUsesWith(ci);
					to_delete.push_back(&i);
					
				} else {
					for(Instruction::op_iterator op_iter = i.op_begin(); op_iter != i.op_end(); op_iter++) {
						Value* op = *op_iter;
						
						if(isa<Constant>(op)) {
							Constant* c = dyn_cast<Constant>(op);
							
							if(containsConstantFloat(c)) {
								Type* t = op->getType();

								GlobalVariable* g = new GlobalVariable(m, t, true, GlobalVariable::InternalLinkage, c, "fconst");
								
								Instruction* insertion_point = &i;
								
								if(isa<PHINode>(insertion_point)) {
									PHINode* phi = dyn_cast<PHINode>(insertion_point);
									BasicBlock *incoming = phi->getIncomingBlock(*op_iter);
									insertion_point = incoming->getTerminator();
								}

								LoadInst* load = new LoadInst(g, "fconst.load", insertion_point);

								if(isa<PHINode>(&i)) {
									PHINode* phi = dyn_cast<PHINode>(op_iter->getUser());
									BasicBlock* incoming = phi->getIncomingBlock(*op_iter);
									while(phi->getBasicBlockIndex(incoming) != -1) {
										phi->removeIncomingValue(incoming, false);
									}
									phi->addIncoming(load, incoming);

								} else {
									op_iter->set(load);
								}
							}
						}
					}
				}
			}
		}

		for(vector<Instruction*>::iterator i_iter = to_delete.begin();
			i_iter != to_delete.end(); i_iter++) {
			
			Instruction* i = *i_iter;
			i->eraseFromParent();
		}
	}
	
	/**
	 * \brief Check if a constant value contains a floating point constant
	 * \arg c The constant to check
	 * \returns true if c is a ConstantFP or contains a ConstantFP
	 */
	bool containsConstantFloat(Constant* c) {
		if(isa<ConstantFP>(c)) {
			return true;
			
		} else if(isa<ConstantExpr>(c)) {
			
			for(Constant::op_iterator op_iter = c->op_begin(); op_iter != c->op_end(); op_iter++) {
				Constant* op = dyn_cast<Constant>(op_iter->get());
				
				if(containsConstantFloat(op)) {
					return true;
				}
			}
		}
		
		return false;
	}
	
	/**
	 * \brief Get a function to convert between floating point and integer types
	 * Extracts floating point conversion operations into an unrandomized function,
	 * which sidesteps issues caused by implicit global references by the ftosi,
	 * ftoui, uitof, and sitof instructions.
	 * 
	 * \arg m The module being processed
	 * \arg in The type of the input value (some float or int type)
	 * \arg out The type of the output value (some float or int type)
	 * \arg is_signed If true, the function should generate a signed integer conversion
	 * \returns A pointer to a function that performs the required type conversion
	 */
	Function* getFloatConversion(Module& m, unsigned opcode, Type* in, Type* out) {
		// LLVM stream bullshit
		string name;
		raw_string_ostream ss(name);
		
		if(opcode == Instruction::FPToUI) {
			ss << "fptoui";
			
		} else if(opcode == Instruction::FPToSI) {
			ss << "fptosi";
			
		} else if(opcode == Instruction::UIToFP) {
			ss << "uitofp";
			
		} else if(opcode == Instruction::SIToFP) {
			ss << "sitofp";
		
		} else if(opcode == Instruction::FPTrunc) {
			ss << "fptrunc";
		
		} else {
			errs() << "Invalid float conversion arguments\n";
			errs() << "  opcode: " << opcode << "\n";
			
			errs() << "  in: ";
			in->print(errs());
			errs() << "\n";
			
			errs() << "  out: ";
			out->print(errs());
			errs() << "\n";
			
			abort();
		}

		// Include in and out types in the function name
		ss<<".";
		in->print(ss);
		ss<<".";
		out->print(ss);

		// Check the module for a function with this name
		Function *f = m.getFunction(ss.str());

		// If not found, create the function
		if(f == NULL) {
			vector<Type*> params;
			params.push_back(in);
		
			f = Function::Create(
				FunctionType::get(out, params, false),
				Function::InternalLinkage,
				ss.str(),
				&m
			);

			BasicBlock *b = BasicBlock::Create(m.getContext(), "", f);
			Instruction *r;

			// Insert the required conversion instruction
			if(opcode == Instruction::FPToUI) {
				r = new FPToUIInst(&*f->arg_begin(), out, "", b);

			} else if(opcode == Instruction::FPToSI) {
				r = new FPToSIInst(&*f->arg_begin(), out, "", b);

			} else if(opcode == Instruction::UIToFP) {
				r = new UIToFPInst(&*f->arg_begin(), out, "", b);

			} else if(opcode == Instruction::SIToFP) {
				r = new SIToFPInst(&*f->arg_begin(), out, "", b);
				
			} else if(opcode == Instruction::FPTrunc) {
				r = new FPTruncInst(&*f->arg_begin(), out, "", b);
			}

			ReturnInst::Create(m.getContext(), r, b);
		}

		return f;
	}
	
	/**
	 * \brief Replace all heap calls with references to Stabilizer's randomized
	 * heap.
	 * 
	 * \arg m The module to transform
	 */
	void randomizeHeap(Module& m) {
		Function *malloc_fn = m.getFunction("malloc");
		Function *calloc_fn = m.getFunction("calloc");
		Function *realloc_fn = m.getFunction("realloc");
		Function *free_fn = m.getFunction("free");

		if(malloc_fn) {
			Function *stabilizer_malloc = Function::Create(
				 malloc_fn->getFunctionType(),
				 Function::ExternalLinkage,
				 "stabilizer_malloc",
				 &m
			);

			malloc_fn->replaceAllUsesWith(stabilizer_malloc);
		}

		if(calloc_fn) {
			Function *stabilizer_calloc = Function::Create(
				 calloc_fn->getFunctionType(),
				 Function::ExternalLinkage,
				 "stabilizer_calloc",
				 &m
			);

			calloc_fn->replaceAllUsesWith(stabilizer_calloc);
		}

		if(realloc_fn) {
			Function *stabilizer_realloc = Function::Create(
				 realloc_fn->getFunctionType(),
				 Function::ExternalLinkage,
				 "stabilizer_realloc",
				 &m
			);

			realloc_fn->replaceAllUsesWith(stabilizer_realloc);
		}

		if(free_fn) {
			Function *stabilizer_free = Function::Create(
				 free_fn->getFunctionType(),
				 Function::ExternalLinkage,
				 "stabilizer_free",
				 &m
			);

			free_fn->replaceAllUsesWith(stabilizer_free);
		}
	}
	
	/**
	 * \brief Declare all of Stabilizer's runtime functions
	 * \arg m The module to transform
	 */
	void declareRuntimeFunctions(Module& m) {
		// Declare the register_function runtime function
		registerFunction = Function::Create(
			 TypeBuilder<void(i<8>*, i<8>*, i<8>*, i<32>, i<1>), true>::get(m.getContext()),
			 Function::ExternalLinkage,
			 "stabilizer_register_function",
			 &m
		);
		
		// Declare the register_constructor runtime function
		registerConstructor = Function::Create(
			TypeBuilder<void(void()), true>::get(m.getContext()),
			Function::ExternalLinkage,
			"stabilizer_register_constructor",
			&m
		);
		
		// Declare the stack_padding runtime function
		stackPadding = Function::Create(
			TypeBuilder<i<64>(), true>::get(m.getContext()),
			Function::ExternalLinkage,
			"stabilizer_stack_padding",
			&m
		);
	}
};

char StabilizerPass::ID = 0;
static RegisterPass<StabilizerPass> X("stabilize", "Add support for runtime randomization of program layout");
