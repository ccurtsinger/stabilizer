// -*- C++ -*-

#ifndef _CHECK_H_
#define _CHECK_H_

template <class C>
class Check {
public:

  Check (C item)
    : _item (item)
  {
#ifndef NDEBUG
    _item->check();
#endif
  }

  ~Check (void) {
#ifndef NDEBUG
    _item->check();
#endif
  }

private:

  C _item;

};

#endif
