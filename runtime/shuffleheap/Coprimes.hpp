#ifndef _COPRIMES_H_
#define _COPRIMES_H_

constexpr size_t min(size_t x, size_t y) {
	return x > y ? y : x;
}

constexpr size_t gcd(size_t x, size_t y) {
	return y == 0 ? x : gcd(y, x % y);
}

constexpr bool coprime(size_t x, size_t y) {
	return gcd(x, y) == 1;
}

constexpr size_t next_coprime(size_t x, size_t y) {
	return coprime(x, y+1) ? y+1 : next_coprime(x, y+1);
}

template<size_t X, size_t Count, bool Spacer, size_t Y, size_t... Coprime> struct CoprimeTable;

template<size_t X, bool Spacer, size_t Y, size_t... Coprimes> struct CoprimeTable<X, 0, Spacer, Y, Coprimes...> {
	
	static inline size_t get(size_t i) {
		const size_t value[] = {Coprimes..., Y};
		return value[i];
	}
};

template<size_t X, size_t Count, bool Spacer, size_t Y, size_t... Coprimes> struct CoprimeTable {
	static inline size_t get(size_t i) {
		return CoprimeTable<X, Count-1, Spacer, next_coprime(X, Y), Coprimes..., Y>::get(i);
	}
};

template<size_t X, size_t Count> struct Coprimes {
	static inline size_t get(size_t i) {
		return CoprimeTable<X, min(Count, 1024), true, 1>::get(i % Count);
	}
};

#endif
