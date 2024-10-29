/+
+            Copyright 2022 – 2024 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module bindbc.common.types;

version(WebAssembly) version = NoStdC;

//c_long; c_ulong
version(NoStdC){
	static if((void*).sizeof > int.sizeof){
		alias c_long  = long;
		alias c_ulong = ulong;
	}else{
		private enum __c_long  : int;
		private enum __c_ulong : uint;
		alias c_long  = __c_long;
		alias c_ulong = __c_ulong;
	}
}else{
	static import core.stdc.config;
	alias c_long = core.stdc.config.c_long;
	alias c_ulong = core.stdc.config.c_ulong;
}

//c_longlong; c_ulonglong
private enum __c_longlong  : long;
private enum __c_ulonglong : ulong;
alias c_longlong  = __c_longlong;
alias c_ulonglong = __c_ulonglong;

//c_int64; c_uint64
version(NoStdC){
	alias c_int64 = long;
	alias c_uint64 = ulong;
}else{
	static import core.stdc.stdint;
	alias c_int64 = core.stdc.stdint.int64_t;
	alias c_uint64 = core.stdc.stdint.uint64_t;
}

//va_list
version(NoStdC){
	alias va_list = void*;
}else{
	static import core.stdc.stdarg;
	alias va_list = core.stdc.stdarg.va_list;
}

//wchar_t
static if((){
	version(Posix)            return true;
	else version(WebAssembly) return true;
	else return false;
}()){
	alias wchar_t = dchar;
}else static if((){
	version(Windows)     return true;
	else version(WinRT)  return true;
	else version(WinGDK) return true;
	else return false;
}()){
	alias wchar_t = wchar;
}else static assert(0, "`sizeof(wchar_t)` is not known on this platform. Please add it to bindbc/common/types.d");
