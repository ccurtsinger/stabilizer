/**
 * Macros for target-specific code.
 */

#if !defined(RUNTIME_ARCH_H)
#define RUNTIME_ARCH_H

#if defined(__APPLE__)
#	define _OSX(x) x
#	define IS_OSX 1
#else
#	define _OSX(x)
#	define IS_OSX 0
#endif

#if defined(__linux__)
#	define _LINUX(x) x
#	define IS_LINUX 1
#else
#	define _LINUX(x)
#	define IS_LINUX 0
#endif

#if defined(__i386__)
#	define _X86(x) x
#	define _AnyX86(x) x
#	define IS_X86 1
#else
#	define _X86(x)
#	define IS_X86 0
#endif

#if defined(__x86_64__)
#	define _X86_64(x) x
#	define _AnyX86(x) x
#	define IS_X86_64 1
#else
#	define _X86_64(x)
#	define IS_X86_64 0
#endif

#if defined(__powerpc__) || defined(__ppc__)
#	define _PPC(x) x
#	define _AnyX86(x)
#	define IS_PPC 1
#else
#	define _PPC(x)
#	define IS_PPC 0
#endif

#endif
