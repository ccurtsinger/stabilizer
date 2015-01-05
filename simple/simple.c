#include <stdio.h>

void __attribute__((constructor)) ctor() {
  printf("In constructor\n");
}

void __attribute__((destructor)) dtor() {
  printf("In destructor\n");
}

int fact(int n) {
  if(n <= 1) return 1;
  else return n * fact(n-1);
}

int main() {
  printf("Here I am\n");
  int i = fact(5);
  return 0;
}

