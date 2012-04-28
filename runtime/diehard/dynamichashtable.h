// -*- C++ -*-

#ifndef DYNAMICHASHTABLE_H_
#define DYNAMICHASHTABLE_H_

#include <sys/mman.h>
#include <stdint.h>

#include "sassert.h"

template <class KEY_TYPE,
	  class VALUE_TYPE,
	  class SourceHeap,
	  size_t INIT_SIZE = 4096>

class DynamicHashTable {

  typedef unsigned int UINT;

  // The maximum load factor for the hash table.
  static const float MaxLoadFactor = 0.125;

  // When we grow the hash table, we multiply its size by this expansion factor.
  // NOTE: This *must* be a power of two.
  enum { ExpansionFactor = 2 };

public:

  DynamicHashTable() :
    _entries (NULL),
    _map_size (INIT_SIZE / sizeof(VALUE_TYPE)),
    _mask (_map_size-1)
  {
    sassert<((ExpansionFactor & (ExpansionFactor-1)) == 0)> verifyPowerOfTwo;
    verifyPowerOfTwo = verifyPowerOfTwo;
    _entries = (VALUE_TYPE *) allocTable (_map_size);
  }
  
  ~DynamicHashTable() {
    for (UINT i = 0; i < _map_size; i++) {
      _entries[i].~VALUE_TYPE();
    }
  }

  VALUE_TYPE * get (KEY_TYPE ptr) const {
    VALUE_TYPE * ret = find (ptr);
    return ret;
  }

  /** Inserts the given site into the map.
   *  Precondition: no site with a matching hash value is in the map.
   */
  // XXX: change to bitwise operations for speed
  void insert (const VALUE_TYPE & s) 
  {
    //fprintf(stderr,"inserting, now %d/%d\n",_num_elts,_map_size);
    
    if(_num_elts+1 > MaxLoadFactor * _map_size) {
      grow();
    } 
    
    _num_elts++;

    int begin = s.getHashCode() & _mask;
    int lim = (begin - 1 + _map_size) & _mask;

    // NB: we don't check slot lim, but we're actually guaranteed never to get 
    // there since the load factor can't be 1.0
    for (int i = begin; i != lim; i = (i+1)&_mask) {
      if (_entries[i].isValid()) {
        assert(_entries[i].getHashCode() != s.getHashCode());
        continue;
      } else {
	// invoke copy constructor via placement new
	new (&_entries[i]) VALUE_TYPE(s);
	return;
      }
    }

    assert(false);
  }

private:

  void grow() 
  {
    //fprintf(stderr,"growing, old map size: %d\n",_num_elts);

    VALUE_TYPE * old_entries = _entries;
    size_t old_map_size = _map_size;

    _entries = (VALUE_TYPE *) allocTable (_map_size * ExpansionFactor);
    _map_size *= ExpansionFactor;
    _mask = _map_size-1;
    
    unsigned int old_elt_count = _num_elts;
    old_elt_count = old_elt_count;

    _num_elts = 0;
	
    // rehash

    unsigned int ct = 0;

    for (unsigned int i = 0; i < old_map_size; i++) {
      if (old_entries[i].isValid()) {
        ct++;
        insert (old_entries[i]);
      }
    }

    //fprintf(stderr,"new map size: %d\n",_num_elts);

    assert (ct == old_elt_count);

    SourceHeap::free (old_entries); // , _map_size / ExpansionFactor * sizeof(VALUE_TYPE));
    //    MmapWrapper::unmap (old_entries, _map_size / ExpansionFactor * sizeof(VALUE_TYPE));
  }


  VALUE_TYPE * find (KEY_TYPE key) const 
  {
    int begin = key & _mask;
    int lim = (begin - 1 + _map_size) & _mask;

    int probes = 0;
    probes = probes;

    for (int i = begin; i != lim; i = (i+1) & _mask) {
      //fprintf(stderr,"probing entry %d\n",i);
#if 0
      probes++;
      if(probes % 10 == 0) {
        // XXX: fix hash function to lower clustering?
	char buf[255];
	sprintf (buf, "probed a lot of times: %d - %d\n", probes, _map_size);
	printf (buf);
      }
#endif
      //fprintf(stderr,"address is %p\n",&_entries[i]);
      ///fprintf(stderr,"content %d\n",*((int *)(&_entries[i])));

      if(_entries[i].isValid()) {
        //fprintf(stderr,"address is %p\n",&_entries[i]);

        if(_entries[i].getHashCode() == key) {
          return &_entries[i];
        } else { 
          continue;
        }
      } else {
        return 0;
      }
    }

    // path cannot be reached---must find empty bin since load factor < 1.0

    abort();
    return 0;
  }

  void * allocTable (int nElts) 
  {
    //fprintf(stderr,"allocating %d bytes\n",nElts*sizeof(VALUE_TYPE));
    void * ptr = 
      SourceHeap::malloc (nElts * sizeof(VALUE_TYPE));
      // MmapWrapper::map (nElts * sizeof(VALUE_TYPE));
    return ptr;
  }
  
  VALUE_TYPE * _entries;
  char * _addrspace;
  size_t _map_size;
  size_t _mask;
  size_t _num_elts;
};

#endif // PAGETABLE_H_
