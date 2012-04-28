// -*- C++ -*-

#ifndef SINGLETON_H_
#define SINGLETON_H_

#include <new>

template <class C>
class singleton : public C {
public:

  static inline C& getInstance() {
    static char buf[sizeof(C)];
    static C * theSingleton = new (buf) C;
    return *theSingleton;
  }

};

#endif

