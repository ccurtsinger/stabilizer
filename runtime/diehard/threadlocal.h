#ifndef _THREADLOCAL_H_
#define _THREADLOCAL_H_

#include <pthread.h>


/**
 * @file   threadlocal.h
 * @brief  A wrapper to provide easy thread-local variables.
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 *
 * Copyright (C) 2010 Emery Berger, University of Massachusetts Amherst
 */

/*
  Example usage:

  threadlocal<int> myInt; // Each thread has its own version of myInt.

  // To get access to the variable, cast it to a pointer and dereference it.

  *((int *) myInt) = 12; 
  cout << *((int *) myInt) << endl; // prints 12

  threadlocal<myClass> mc;
  ((myClass *) mc)->doSomething(); // each thread does its own thing

*/

#if 1

template <class Type>
class threadlocal {
public:

  threadlocal()
  {
  }

  ~threadlocal() {
  }

  inline operator Type * (void) {
    return &v;
  }
  
private:
  Type v;
};

#else

template <class Type>
class threadlocal {
public:

  threadlocal()
  {
    pthread_key_create (&key, threadlocal::cleanUp);
  }

  ~threadlocal() {
    pthread_key_delete (key);
  }

  static void cleanUp (void * v) {
    munmap (v, sizeof(Type));
  }

  operator Type * (void) const {
    void * v = pthread_getspecific (key);
    if (v == NULL) {
      void * buf = mmap (NULL, sizeof(Type), PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
      v = (void *) new (buf) Type;
      pthread_setspecific (key, v);
    }
    return (Type *) v;
  }
  
private:
  pthread_key_t key;

};

#endif

#endif
