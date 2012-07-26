#ifndef _LIST_H_
#define _LIST_H_

#include "Util.h"
#include "Heaps.h"
#include <cassert>

template<typename T, bool UseMDHeap=true> struct list {
private:
	struct list_node {
		T value;
		list_node* next;
		list_node(T value, list_node* next) : value(value), next(next) {}
		void* operator new(size_t sz) {
			if(UseMDHeap) {
				return MD_malloc(sz);
			} else {
				return malloc(sz);
			}
		}
		void operator delete(void* p) {
			if(UseMDHeap) {
				MD_free(p);
			} else {
				free(p);
			}
		}
	};
	
	struct list_iterator {
		list_node** head;
		size_t* counter;
		list_node* current;
		list_node* previous;
		bool doRemove;
		
		list_iterator(list_node** head, size_t* counter, list_node* current) {
			this->head = head;
			this->counter = counter;
			this->current = current;
			this->previous = NULL;
			this->doRemove = false;
		}
		
		void next() {
			if(doRemove) {
				if(previous == NULL) {
					*head = current->next;
				} else {
					previous->next = current->next;
				}
				*counter = *counter - 1;
				list_node* c = current;
				current = current->next;
				delete c;
			} else {
				previous = current;
				current = current->next;
			}
			doRemove = false;
		}
		
		void remove() {
			doRemove = true;
		}
		
		bool operator!=(list_iterator iter) {
			return this->current != iter.current;
		}
		
		void operator++() {
			this->next();
		}
		
		T operator*() {
			assert(current != NULL && "Attempted to reference end() in list_iterator");
			return current->value;
		}
	};
	
	list_node* head;
	size_t count;
	
public:
	typedef list_iterator iter;
	
	list() {
		head = NULL;
		count = 0;
	}
	
	void add(T value) {
		head = new list_node(value, head);
		count++;
	}
	
	void append(T value) {
		if(head == NULL) {
			head = new list_node(value, head);
		} else {
			list_node* c = head;
			while(c->next != NULL) {
				c = c->next;
			}
			c->next = new list_node(value, NULL);
		}
		count++;
	}
	
	size_t size() {
		return count;
	}
	
	list_iterator begin() {
		return list_iterator(&head, &count, head);
	}
	
	list_iterator end() {
		return list_iterator(NULL, NULL, NULL);
	}
};

#endif
