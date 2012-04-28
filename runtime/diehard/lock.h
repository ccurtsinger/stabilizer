// -*- C++ -*-

#ifndef _LOCK_H_
#define _LOCK_H_

extern volatile int anyThreadCreated;

#if defined(__APPLE__)

#include <libkern/OSAtomic.h>

class Lock {
public:

  Lock (void)
    : _lock (OS_SPINLOCK_INIT)
  {}

  void lock (void) {
    OSSpinLockLock (&_lock);
  }

  void unlock (void) {
    OSSpinLockUnlock (&_lock);
  }

private:
  volatile OSSpinLock _lock;
};

#elif defined(_WIN32)

#define _MM_PAUSE {__asm{_emit 0xf3};__asm {_emit 0x90}}

class Lock {
public:

  Lock (void)
    : _lock (0)
  {
  }

  inline void lock (void) {
    if (anyThreadCreated)
      while (InterlockedExchange ((long *) &_lock, 1) != 0) {
	while (_lock == 1) {
	  _MM_PAUSE;
	  // Give up the current scheduling quantum.
	  Sleep (0);
	}
      }
  }

  inline void unlock (void) {
    if (anyThreadCreated) {
#if defined(_MSC_VER)
      __asm {}
#endif
      // was: _lock = 0;
      InterlockedExchange ((long *) &_lock, 0);
    }
  }

private:

  volatile long _lock;

};

#else

#include <pthread.h>

class Lock {
public:
  Lock (void)
  {
    // Here's what I would like to do:
    //   pthread_mutex_init (&_lock, NULL);
    // But I cannot.
    //
    // This is ugly. Initialize the lock to the default without
    // potentially calling malloc, which otherwise leads to an
    // infinite loop when this is used in a malloc-replacement. I
    // would prefer to use a "POSIX standard" mutex initializer --
    // e.g., PTHREAD_MUTEX_INITIALIZER -- but Linux doesn't
    // necessarily define it.

    memset (&_lock, 0, sizeof(pthread_mutex_t));
  }

  inline void lock (void) {
    //    if (anyThreadCreated)
      pthread_mutex_lock (&_lock);
  }

  inline void unlock (void) {
    //    if (anyThreadCreated)
      pthread_mutex_unlock (&_lock);
  }
  
private:
  //  pthread_mutexattr_t _attr;
  pthread_mutex_t _lock;

};


#endif


#endif // _LOCK_H_
