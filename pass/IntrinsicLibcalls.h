/*
 * IntrinsicLibcalls.h
 *
 *  Created on: Apr 2, 2010
 *      Author: charlie
 */

#ifndef INTRINSICLIBCALLS_H_
#define INTRINSICLIBCALLS_H_

#include <map>
#include <set>

using namespace std;
using namespace llvm;

map<StringRef, StringRef> libcall_map;

set<StringRef> inlined;

void InitLibcalls() {
	inlined.insert("llvm.va_start");
	inlined.insert("llvm.va_copy");
	inlined.insert("llvm.va_end");

	inlined.insert("llvm.objectsize.i8");
	inlined.insert("llvm.objectsize.i16");
	inlined.insert("llvm.objectsize.i32");
	inlined.insert("llvm.objectsize.i64");

	inlined.insert("llvm.bswap.i8");
	inlined.insert("llvm.bswap.i16");
	inlined.insert("llvm.bswap.i32");

	inlined.insert("llvm.stacksave");
	inlined.insert("llvm.stackrestore");
	inlined.insert("llvm.trap");
	
	inlined.insert("llvm.uadd.with.overflow.i64");
	
	inlined.insert("llvm.eh.exception");
	inlined.insert("llvm.eh.selector");

	libcall_map["llvm.memcpy.p0i8.p0i8.i8"]	=  "memcpy";
	libcall_map["llvm.memcpy.p0i8.p0i8.i16"] = "memcpy";
	libcall_map["llvm.memcpy.p0i8.p0i8.i32"] = "memcpy";
	libcall_map["llvm.memcpy.p0i8.p0i8.i64"] = "memcpy";
	
	libcall_map["llvm.memcpy.i8"] =  "memcpy";
	libcall_map["llvm.memcpy.i16"] = "memcpy";
	libcall_map["llvm.memcpy.i32"] = "memcpy";
	libcall_map["llvm.memcpy.i64"] = "memcpy";

	libcall_map["llvm.memmove.p0i8.p0i8.i8"] =  "memmove";
	libcall_map["llvm.memmove.p0i8.p0i8.i16"] = "memmove";
	libcall_map["llvm.memmove.p0i8.p0i8.i32"] = "memmove";
	libcall_map["llvm.memmove.p0i8.p0i8.i64"] = "memmove";
	
	libcall_map["llvm.memmove.i8"] =  "memmove";
	libcall_map["llvm.memmove.i16"] = "memmove";
	libcall_map["llvm.memmove.i32"] = "memmove";
	libcall_map["llvm.memmove.i64"] = "memmove";

	libcall_map["llvm.memset.p0i8.i8"] =  "memset";
	libcall_map["llvm.memset.p0i8.i16"] = "memset";
	libcall_map["llvm.memset.p0i8.i32"] = "memset";
	libcall_map["llvm.memset.p0i8.i64"] = "memset";
	
	libcall_map["llvm.memset.i8"] =  "memset";
	libcall_map["llvm.memset.i16"] = "memset";
	libcall_map["llvm.memset.i32"] = "memset";
	libcall_map["llvm.memset.i64"] = "memset";

	libcall_map["llvm.sqrt.f32"] = "sqrtf";
	libcall_map["llvm.sqrt.f64"] = "sqrt";
	libcall_map["llvm.sqrt.f80"] = "sqrtl";

	libcall_map["llvm.log.f32"] = "logf";
	libcall_map["llvm.log.f64"] = "log";
	libcall_map["llvm.log.f80"] = "logl";

	libcall_map["llvm.exp.f32"] = "expf";
	libcall_map["llvm.exp.f64"] = "exp";
	libcall_map["llvm.exp.f80"] = "expl";

	libcall_map["llvm.pow.f32"] = "powf";
	libcall_map["llvm.pow.f64"] = "pow";
	libcall_map["llvm.pow.f80"] = "powl";

	libcall_map["llvm.log10.f32"] = "log10f";
	libcall_map["llvm.log10.f64"] = "log10";
	libcall_map["llvm.log10.f80"] = "log10l";
}

bool isAlwaysInlined(StringRef intrinsic) {
	return inlined.find(intrinsic) != inlined.end();
}

StringRef GetLibcall(StringRef intrinsic) {
	return libcall_map[intrinsic];
	map<StringRef, StringRef>::iterator i = libcall_map.find(intrinsic);
	if(i == libcall_map.end()) {
		return "";
	} else {
		return i->second;
	}
}

#endif /* INTRINSICLIBCALLS_H_ */
