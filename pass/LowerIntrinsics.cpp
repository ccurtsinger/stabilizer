#define DEBUG_TYPE "lower_intrinsics"

#include <iostream>

#include "llvm/Module.h"
#include "llvm/Pass.h"
#include "llvm/Instructions.h"

#include "llvm/Support/raw_ostream.h"

#include "IntrinsicLibcalls.h"

using namespace std;
using namespace llvm;

struct LowerIntrinsics: public ModulePass {
	static char ID;
	
	LowerIntrinsics() : ModulePass(ID) {
	}
	
	virtual bool runOnModule(Module &m) {
		InitLibcalls();
		
		for(Module::iterator fun = m.begin(); fun != m.end(); fun++) {
			Function &f = *fun;
			if(f.isIntrinsic() && !isAlwaysInlined(f.getName())) {
				StringRef r = GetLibcall(f.getName());
				
				if(!r.empty()) {
					Function *f_extern = m.getFunction(r);
					if(!f_extern) {
						f_extern = Function::Create(
							f.getFunctionType(),
							Function::ExternalLinkage,
							r,
							&m
						);
					}
					f.replaceAllUsesWith(f_extern);
				} else {
					errs()<<"warning: unable to handle intrinsic "<<f.getName().str()<<"\n";
				}
			}
		}
		
		return true;
	}
};

char LowerIntrinsics::ID = 0;
static RegisterPass<LowerIntrinsics> X("lower-intrinsics", "Replace all intrinsics with direct libcalls");
