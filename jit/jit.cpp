#include <llvm/ExecutionEngine/RTDyldMemoryManager.h>
#include <llvm/ExecutionEngine/GenericValue.h>
#include <llvm/ExecutionEngine/Interpreter.h>
#include <llvm/ExecutionEngine/MCJIT.h>
#include <llvm/ExecutionEngine/ObjectCache.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/IRReader/IRReader.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/ManagedStatic.h>
#include "llvm/Support/Path.h"
#include <llvm/Support/raw_ostream.h>
#include <llvm/Support/SourceMgr.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/Transforms/Instrumentation.h>
#include <llvm/Transforms/Utils/Cloning.h>

#include <string>
#include <vector>

#include <errno.h>
#include <fcntl.h>
#include <mach/mach_time.h>
#include <sys/mman.h>

using namespace llvm;
using namespace std;

enum { PageSize = 0x1000 };

class CustomAllocator : public RTDyldMemoryManager {
public:
  virtual uint8_t* allocateCodeSection(uintptr_t sz, unsigned align, unsigned id, StringRef name) {
    uintptr_t sz_rem = sz % PageSize;
    if(sz_rem != 0) sz += PageSize - sz_rem;
    void* p = mmap(NULL, sz, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_SHARED, -1, 0);
    //fprintf(stderr, "%s (code) at %p\n", name.str().c_str(), p);
    return (uint8_t*)p;
  }
  
  virtual uint8_t* allocateDataSection(uintptr_t sz, unsigned align, unsigned id, StringRef name, bool read_only) {
    uintptr_t sz_rem = sz % PageSize;
    if(sz_rem != 0) sz += PageSize - sz_rem;
    void* p = mmap(NULL, sz, PROT_READ | PROT_WRITE, MAP_ANON | MAP_SHARED, -1, 0);
    //fprintf(stderr, "%s (data) at %p\n", name.str().c_str(), p);
    return (uint8_t*)p;
  }
  
  virtual bool finalizeMemory(std::string* err) {
    return false;
  }
};

Module* readModule(const string& filename, LLVMContext& context) {
  SMDiagnostic err;
  Module* m = ParseIRFile(filename, err, context);
  
  if(!m) {
    err.print(filename.c_str(), outs());
  }
  
  return m;
}

vector<Module*> splitModule(Module* M) {
  vector<Module*> modules;
  vector<GlobalValue*> to_remove;
  
  // Mark all globals as external
  for(GlobalVariable& other : M->getGlobalList()) {
    if(other.getName() != "llvm.global_ctors" && other.getName() != "llvm.global_dtors") {
      other.setLinkage(GlobalValue::ExternalLinkage);
    }
  }
  
  // Extract each function into a separate module
  for(Function& F : M->getFunctionList()) {
    if(!F.isDeclaration()) {
      outs() << "Extracting function " << F.getName() << "\n";
      Module* newM = CloneModule(M);
    
      // Delete other functions in the module
      for(Function& other : newM->getFunctionList()) {
        if(!other.isDeclaration() && other.getName() != F.getName()) {
          other.deleteBody();
        }
      }
    
      // Delete globals in the module
      for(GlobalVariable& other : newM->getGlobalList()) {
        if(other.getName() != "llvm.global_ctors" && other.getName() != "llvm.global_dtors") {
          other.setInitializer(NULL);
        } else {
          to_remove.push_back(&other);
        }
      }
    
      // Add this to the list of modules
      modules.push_back(newM);
    
      // Remove this function's body from the main module
      F.deleteBody();
    }
  }
  
  for(GlobalValue* r : to_remove) {
    r->eraseFromParent();
  }
  
  modules.push_back(M);
  
  return modules;
}

int main(int argc, char** argv, char** envp) {
  InitializeNativeTarget();
  //InitializeAllTargetMCs();
  InitializeNativeTargetAsmPrinter();
  //LLVMLinkInMCJIT();

  // Use a single LLVM context
  LLVMContext Context;
  
  // Read in the module bitcode file
  Module* M = readModule(argv[1], Context);
  
  vector<Module*> modules = splitModule(M);
  
  // Use a custom allocator for the JIT
  CustomAllocator* memory_manager = new CustomAllocator();
  
  Module* m1 = modules.back();
  modules.pop_back();
  
  // Create the JIT
  ExecutionEngine* EE = EngineBuilder(m1).setOptLevel(CodeGenOpt::Default)
                                         .setUseMCJIT(true)
                                         .setMCJITMemoryManager(memory_manager)
                                         .create();
  
  // Add all other modules
  for(Module* m : modules) {
    EE->addModule(m);
  }
  
  // Generate code
  EE->finalizeObject();

  // Call the `main' function with no arguments:
  vector<string> args;
  for(int i=1; i<argc; i++) {
    args.push_back(string(argv[i]));
  }
  
  // Find the entry point
  Function* F = EE->FindFunctionNamed("main");
  if(!F) {
    outs() << "Module doesn't define a main function!\n";
    return 1;
  }
  
  size_t start_time = mach_absolute_time();
  EE->runStaticConstructorsDestructors(false);
  int rc = EE->runFunctionAsMain(F, args, envp);
  EE->runStaticConstructorsDestructors(true);
  float runtime = (float)(mach_absolute_time() - start_time) / 1000000000;
  outs() << "Runtime: " << runtime << "\n";

  // Import result of execution:
  outs() << "Result: " << rc << "\n";

  delete EE;
  llvm_shutdown();
  return 0;
}
