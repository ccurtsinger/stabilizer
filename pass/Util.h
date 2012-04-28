
#ifndef PASS_UTIL_H
#define PASS_UTIL_H

#include <vector>
#include <set>

#include "llvm/Module.h"
#include "llvm/Function.h"
#include "llvm/InstrTypes.h"
#include "llvm/Instructions.h"
#include "llvm/Constants.h"
#include "llvm/Type.h"
#include "llvm/DerivedTypes.h"
#include "llvm/Intrinsics.h"

#include "llvm/Support/raw_ostream.h"

using namespace std;
using namespace llvm;

GlobalVariable* MakeTable(Module &m, StringRef name, vector<Constant*> values);
GlobalVariable* MakeTable(Module &m, StringRef name, vector<GlobalValue*> values);

Function* MakeConstructor(Module &m, StringRef name);

set<Instruction*> Instructify(Value *v);

void GlobifyFloats(Module &m, Value *v);
Function* getFloatConversion(Module &m, const Type *in, const Type *out, bool is_signed);

size_t objectSize(const Type *t);
Value* computeObjectSize(Module &m, const Type *t);

#endif
