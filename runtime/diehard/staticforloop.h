// -*- C++ -*- 

#ifndef _STATICFORLOOP_H_
#define _STATICFORLOOP_H_

template <int From, int Iterations, template <int> class C, typename V>
class StaticForLoop;

template <int From, template <int> class C, typename V>
class StaticForLoop<From, 0, C, V>
{
public:
  static void run (V) {}
};

template <int From, int Iterations, template <int> class C, typename V>
class StaticForLoop {
public:
  static void run (V v)
  {
    C<From>::run (v);
    StaticForLoop<From+1, Iterations-1, C, V> s;
    // Silly workaround for Sun.
    s.run (v);
  }
};

#endif
