
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
#include "llvm/Support/Casting.h"
#include "llvm/Support/TypeBuilder.h"

#include "llvm/ADT/ilist.h"

using namespace std;
using namespace llvm;
using namespace types;

Function* MakeConstructor(Module &m, StringRef name);

#endif
