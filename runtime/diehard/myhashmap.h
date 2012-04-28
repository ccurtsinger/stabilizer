// -*- C++ -*-

#ifndef _HL_MYHASHMAP_H_
#define _HL_MYHASHMAP_H_

#include <assert.h>
#include "hash.h"

namespace HL {

template <typename Key,
	  typename Value,
	  class Allocator>
class MyHashMap {

public:

  MyHashMap (int size = INITIAL_NUM_BINS)
    : num_bins (size)
  {
    bins = new (alloc.malloc (sizeof(ListNodePtr) * num_bins)) ListNodePtr;
    for (int i = 0 ; i < num_bins; i++) {
      bins[i] = NULL;
    }
  }

  void set (Key k, Value v) {
    int binIndex = (unsigned int) hash(k) % num_bins;
    ListNode * l = bins[binIndex];
    while (l != NULL) {
      if (l->key == k) {
	l->value = v;
	return;
      }
      l = l->next;
    }
    // Didn't find it.
    insert (k, v);
  }

  Value get (Key k) {
    int binIndex = (unsigned int) hash(k) % num_bins;
    ListNode * l = bins[binIndex];
    while (l != NULL) {
      if (l->key == k) {
	return l->value;
      }
      l = l->next;
    }
    // Didn't find it.
    return 0;
  }

  void erase (Key k) {
    int binIndex = (unsigned int) hash(k) % num_bins;
    ListNode * curr = bins[binIndex];
    ListNode * prev = NULL;
    while (curr != NULL) {
      if (curr->key == k) {
	// Found it.
	if (curr != bins[binIndex]) {
	  assert (prev->next == curr);
	  prev->next = prev->next->next;
	  alloc.free (curr);
	} else {
	  ListNode * n = bins[binIndex]->next;
	  alloc.free (bins[binIndex]);
	  bins[binIndex] = n;
	}
	return;
      }
      prev = curr;
      curr = curr->next;
    }
  }


private:

  void insert (Key k, Value v) {
    int binIndex = (unsigned int) hash(k) % num_bins;
    ListNode * l = new (alloc.malloc (sizeof(ListNode))) ListNode;
    l->key = k;
    l->value = v;
    l->next = bins[binIndex];
    bins[binIndex] = l;
  }

  enum { INITIAL_NUM_BINS = 511 };

  class ListNode {
  public:
    ListNode (void)
      : next (NULL)
    {}
    Key key;
    Value value;
    ListNode * next;
  };

  int num_bins;

  typedef ListNode * ListNodePtr;
  ListNodePtr * bins;
  Allocator alloc;
};

}

#endif
