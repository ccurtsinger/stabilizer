// -*- C++ -*-

#ifndef _DIEFAST_H_
#define _DIEFAST_H_

// DieFast mixin.

class DieFast {
public:
  
  /// @return true if the given value is not found in the buffer.
  /// @param ptr   the start of the buffer
  /// @param sz    the size of the buffer
  /// @param val   the value to check for
  static bool checkNot (void * const ptr, size_t sz, size_t val) {
    size_t * l = (size_t *) ptr;
    for (int i = 0; i < (int) (sz / sizeof(size_t)); i++) {
      if (l[i] != val)
	return true;
    }
    return false;
  }

  /// @brief fills the buffer with the desired value.
  /// @param ptr   the start of the buffer
  /// @param sz    the size of the buffer
  /// @param val   the value to fill the buffer with
  /// @note  the size must be larger than, and a multiple of, sizeof(double).
  static inline void fill (void * ptr, size_t sz, size_t val) {
    assert (sz >= sizeof(double));
    assert (sz % sizeof(double) == 0);
    size_t * l = (size_t *) ptr;
    for (int i = 0; i < (int) (sz / sizeof(size_t)); i++) {
      *l = val;
      l++;
    }
    return;

  }

};

#endif
