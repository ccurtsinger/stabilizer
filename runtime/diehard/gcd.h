#ifndef GCD_H_
#define GCD_H_

template <int a, int b> struct gcd
{
  static const int value = gcd<b, a%b>::value;
};

template <int a> struct gcd<a, 0>
{
  static const int value = a;
};


#endif
