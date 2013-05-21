/**
 * Macros for target-specific code.
 */

#if !defined(RUNTIME_ARCH_H)
#define RUNTIME_ARCH_H

#if defined(__APPLE__)
    #define _OSX(x) x
#else
    #define _OSX(x)
#endif

#if defined(__linux__)
    #define _LINUX(x) x
#else
    #define _LINUX(x)
#endif

#if defined(__i386__)
    #define _X86(x) x
    #define _AnyX86(x) x
#else
    #define _X86(x)
#endif

#if defined(__x86_64__)
    #define _X86_64(x) x
    #define _AnyX86(x) x
#else
    #define _X86_64(x)
#endif

#if defined(PPC)
    #define _PPC(x) x
    #define _AnyX86(x)
#else
    #define _PPC(x)
#endif

#endif
