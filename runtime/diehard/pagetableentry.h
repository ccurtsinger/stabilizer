#ifndef PAGETABLEENTRY_H_
#define PAGETABLEENTRY_H_

class RandomMiniHeapBase;

class PageTableEntry {
public:
  PageTableEntry (uintptr_t pNum,
		  RandomMiniHeapBase * b,
		  unsigned int idx) 
    : _pageNumber (pNum),
      _heap (b),
      _pageIndex (idx)
  {
    //fprintf(stderr,"%p: %p, %d\n",pNum, b, idx);
  }

 PageTableEntry (const PageTableEntry & rhs)
  : _pageNumber (rhs._pageNumber),
    _heap (rhs._heap),
    _pageIndex (rhs._pageIndex)
  {
  }

  RandomMiniHeapBase * getHeap() const {
    return _heap;
  }

  unsigned int getPageIndex() const {
    return _pageIndex;
  }

  bool isValid() const {
    return _heap != 0;
  }
  
  uintptr_t getHashCode() const {
    return _pageNumber;
  }

private:
  uintptr_t 		_pageNumber;
  RandomMiniHeapBase * 	_heap;
  unsigned int 		_pageIndex;
  uintptr_t 		_align; // EDB for alignment?
};

#endif
