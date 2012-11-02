/* config.h.in.  Generated from configure.in by autoheader.  */
#if defined(SPEC_CPU)

#define PACKAGE_BUGREPORT "libquantum@enyo.de"
#define PACKAGE_NAME "libquantum"
#define PACKAGE_STRING "libquantum 0.2.4"
#define PACKAGE_TARNAME "libquantum"
#define PACKAGE_VERSION "0.2.4"
#define STDC_HEADERS 1
#define COMPLEX_FLOAT float _Complex

#if defined(SPEC_CPU_HPUX) && !defined(inline)
# define inline __inline
#endif

#if defined(SPEC_CPU_NEED_COMPLEX_I)
# define _Complex_I 1.0fi
#endif

#if defined(SPEC_CPU_MACOSX) || defined(SPEC_CPU_AIX) \
    || defined(SPEC_CPU_IRIX) || defined(SPEC_CPU_HPUX) \
    || defined(SPEC_CPU_SOLARIS) || defined(SPEC_CPU_LINUX)
# if !defined(SPEC_CPU_NO_COMPLEX_H)
#  include <complex.h>
# endif
#define HAVE_DLFCN_H 1
#define HAVE_FCNTL_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_LIBM 1
#define HAVE_MEMORY_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRINGS_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#if defined(SPEC_CPU_ICL)
#define IMAGINARY __I__
#else
#define IMAGINARY _Complex_I
#endif /* SPEC_CPU_ICL */
#define MAX_UNSIGNED unsigned long long
#endif /* SPEC_CPU_MACOSX || AIX || IRIX || HPUX || SOLARIS || LINUX */

#if defined(SPEC_CPU_WINDOWS)
# if defined(SPEC_CPU_COMPLEX_I)
#  define IMAGINARY _Complex_I
# else
#  define IMAGINARY __I__
# endif /* SPEC_CPU_COMPLEX_I */
#define MAX_UNSIGNED unsigned __int64
#endif /* SPEC_CPU_WINDOWS */

#else /* SPEC_CPU */

/* Complex data type */
#undef COMPLEX_FLOAT

/* Define to 1 if you have the <dlfcn.h> header file. */
#undef HAVE_DLFCN_H

/* Define to 1 if you have the <fcntl.h> header file. */
#undef HAVE_FCNTL_H

/* Define to 1 if you have the <inttypes.h> header file. */
#undef HAVE_INTTYPES_H

/* Define to 1 if you have the `m' library (-lm). */
#undef HAVE_LIBM

/* Define to 1 if you have the <memory.h> header file. */
#undef HAVE_MEMORY_H

/* Define to 1 if you have the <stdint.h> header file. */
#undef HAVE_STDINT_H

/* Define to 1 if you have the <stdlib.h> header file. */
#undef HAVE_STDLIB_H

/* Define to 1 if you have the <strings.h> header file. */
#undef HAVE_STRINGS_H

/* Define to 1 if you have the <string.h> header file. */
#undef HAVE_STRING_H

/* Define to 1 if you have the <sys/stat.h> header file. */
#undef HAVE_SYS_STAT_H

/* Define to 1 if you have the <sys/types.h> header file. */
#undef HAVE_SYS_TYPES_H

/* Define to 1 if you have the <unistd.h> header file. */
#undef HAVE_UNISTD_H

/* Imaginary unit */
#undef IMAGINARY

/* Integer type for quantum registers */
#undef MAX_UNSIGNED

/* Define to the address where bug reports for this package should be sent. */
#undef PACKAGE_BUGREPORT

/* Define to the full name of this package. */
#undef PACKAGE_NAME

/* Define to the full name and version of this package. */
#undef PACKAGE_STRING

/* Define to the one symbol short name of this package. */
#undef PACKAGE_TARNAME

/* Define to the version of this package. */
#undef PACKAGE_VERSION

/* Define to 1 if you have the ANSI C header files. */
#undef STDC_HEADERS

/* Define as `__inline' if that's what the C compiler calls it, or to nothing
   if it is not supported. */
#undef inline

#endif /* SPEC_CPU */
