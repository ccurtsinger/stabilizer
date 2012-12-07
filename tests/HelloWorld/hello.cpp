#include <stdio.h>

void ctor() __attribute__((constructor));

void ctor() {
	printf("Hello Constructor!\n");
}

int main(int argc, char** argv) {
	printf("Hello World!\n");
	return 0;
}
