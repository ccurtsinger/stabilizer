/* -*- C++ -*- */


#ifndef DEBUGHEAP_H_
#define DEBUGHEAP_H_

#include <assert.h>

#include "gcd.h"

/**
 *
 *
 */

template <class Super>

class DebugHeap : public Super {
private:

  enum { HCANARY = 0xdeadbeef };
  enum { FCANARY = 0xcafed00d };

  class Footer;

  class Header {
    enum { SizeofAllFields = sizeof(Footer) + sizeof(unsigned long) };
    enum { RoundUpSize     = Super::Alignment * ((SizeofAllFields + Super::Alignment - 1) / Super::Alignment) };
    enum { RoundUpOffset   = RoundUpSize - SizeofAllFields };
  public:
    Header (Footer * f) 
      : _footer (f),
	_canary (HCANARY)
    {}
    bool isValid() const {
      return _canary == HCANARY;
    }
    Footer * getFooter() const {
      return _footer;
    }
  private:
    char _buf[RoundUpOffset]; // For alignment.
    Footer * _footer;
    unsigned long _canary;
  };

  class Footer {
  public:
    Footer()
      : _canary (FCANARY)
    {}
    bool isValid() const {
      return _canary == FCANARY;
    }
  private:
    unsigned long _canary;
  };

public:

  inline void * malloc (size_t sz) {
    // Allocate extra space at the beginning and end.
    size_t newsz = sizeof(Header) + sz + sizeof(Footer);
    void * buf = Super::malloc (newsz);
    void * footerPosition = (char *) buf + sizeof(Header) + sz;
    Footer * f = new (footerPosition) Footer;
    Header * h = new (buf) Header (f);
    return (void *) (h + 1);
  }
  
  inline void free (void * ptr) {
    // Pull out the header & footer and check their validity.
    Header * h = (Header *) ptr - 1;
    assert (h->isValid());
    Footer * f = h->getFooter();
    assert (f->isValid());
    Super::free (h);
  }

  inline size_t getSize (void * ptr) {
    Header * h = (Header *) ptr - 1;
    return Super::getSize (h);
  }

};

#endif
