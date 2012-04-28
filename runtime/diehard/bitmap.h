// -*- C++ -*-


/**
 * @file   bitmap.h
 * @brief  A bitmap class, with one bit per element.
 * @author Emery Berger <http://www.cs.umass.edu/~emery>
 * @note   Copyright (C) 2005 by Emery Berger, University of Massachusetts Amherst.
 */


#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "staticlog.h"

#ifndef _BITMAP_H_
#define _BITMAP_H_

/**
 * @class BitMap
 * @brief Manages a dynamically-sized bitmap.
 * @param Heap  the source of memory for the bitmap.
 */

template <class Heap>
class BitMap : private Heap {
public:

  BitMap (void)
    : _bitarray (NULL),
      _elements (0)
  {
  }

  /**
   * @brief Sets aside space for a certain number of elements.
   * @param  nelts  the number of elements needed.
   */
  
  void reserve (unsigned long long nelts) {
    if (_bitarray) {
      Heap::free (_bitarray);
    }
    // Round up the number of elements.
    _elements = WORDBITS * ((nelts + WORDBITS - 1) / WORDBITS);
    // Allocate the right number of bytes.
    unsigned int nbytes = _elements / WORDBYTES;
    void * buf = Heap::malloc ((size_t) nbytes);
    _bitarray = (WORD *) buf;
    clear();
  }

  /// Clears out the bitmap array.
  void clear (void) {
    if (_bitarray != NULL) {
      unsigned int nbytes = _elements / WORDBYTES;
      memset (_bitarray, 0, (size_t) nbytes); // 0 = false
    }
  }

  /// @return true iff the bit was not set (but it is now).
  inline bool tryToSet (unsigned long long index) {
    assert (index < _elements);
    const unsigned int item = index >> WORDBITSHIFT;
    const unsigned int position = index & (WORDBITS - 1);
    assert (item < _elements / WORDBYTES);
    unsigned long oldvalue;
    const WORD mask = getMask(position);
    oldvalue = _bitarray[item];
    _bitarray[item] |= mask;
    return !(oldvalue & mask);
  }

  /// Clears the bit at the given index.
  inline bool reset (unsigned long long index) {
    assert (index < _elements);
    const unsigned int item = index >> WORDBITSHIFT;
    const unsigned int position = index & (WORDBITS - 1);
    assert (item < _elements / WORDBYTES);
    unsigned long oldvalue;
    oldvalue = _bitarray[item];
    WORD newvalue = oldvalue &  ~(getMask(position));
    _bitarray[item] = newvalue;
    return (oldvalue != newvalue);
  }

  inline bool isSet (unsigned long long index) const {
    assert (index < _elements);
    const unsigned int item = index >> WORDBITSHIFT;
    const unsigned int position = index - (item << WORDBITSHIFT);
    assert (item < _elements / WORDBYTES);
    bool result = _bitarray[item] & (getMask(position));
    return result;
  }

private:

  /// A synonym for the datatype corresponding to a word.
  typedef size_t WORD;

  /// To find the bit in a word, do this: word & getMask(bitPosition)
  /// @return a "mask" for the given position.
  inline static WORD getMask (unsigned long long pos) {
    return ((WORD) 1) << pos;
  }

  /// The number of bits in a WORD.
  enum { WORDBITS = sizeof(WORD) * 8 };

  /// The number of BYTES in a WORD.
  enum { WORDBYTES = sizeof(WORD) };

  /// The log of the number of bits in a WORD, for shifting.
  enum { WORDBITSHIFT = StaticLog<WORDBITS>::value };

  /// The bit array itself.
  WORD * _bitarray;
  
  /// The number of elements in the array.
  unsigned int _elements;

};

#endif
