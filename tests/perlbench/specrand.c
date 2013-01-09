/*
 ****************************************************************************
 *
 * HEY!
 * 
 * Absolutely do NOT forget to include "specrand.h" in any file in which you
 * call EITHER spec_rand OR spec_srand.
 *
 * Failure to heed this warning will likely result in strange, hard-to-diagnose
 * bugs.  YOU HAVE BEEN WARNED!
 *
 ****************************************************************************
 */
static int seedi;

void spec_srand(int seed) {
  seedi = seed;
}

/* See "Random Number Generators: Good Ones Are Hard To Find", */
/*     Park & Miller, CACM 31#10 October 1988 pages 1192-1201. */
/***********************************************************/
/* THIS IMPLEMENTATION REQUIRES AT LEAST 32 BIT INTEGERS ! */
/***********************************************************/
double spec_rand(void)
#define _A_MULTIPLIER  16807L
#define _M_MODULUS     2147483647L /* (2**31)-1 */
#define _Q_QUOTIENT    127773L     /* 2147483647 / 16807 */
#define _R_REMAINDER   2836L       /* 2147483647 % 16807 */
{
  int lo;
  int hi;
  int test;

  hi = seedi / _Q_QUOTIENT;
  lo = seedi % _Q_QUOTIENT;
  test = _A_MULTIPLIER * lo - _R_REMAINDER * hi;
  if (test > 0) {
    seedi = test;
  } else {
    seedi = test + _M_MODULUS;
  }
  return ( (double) seedi / _M_MODULUS);
}
