/+
+            Copyright 2023 – 2023 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module bindbc.common.types;

static if(__VERSION__ >= 2101L){ //2.101+ supports Import C with #include
	public import bindbc.common.ctypes: c_long, c_ulong;
	
	//these `c_` type aliases are here because these types use #define on some platforms
	private import bindbc.common.ctypes: c_wchar_t, c_va_list;
	alias wchar_t = c_wchar_t;
	alias va_list = c_va_list;
}else{
	version(WebAssembly){
		alias c_long  = long;
		alias c_ulong = ulong;
		
		alias va_list = void*;
	}else{
		public import core.stdc.config: c_long, c_ulong;
		public import core.stdc.stdarg: va_list;
	}
	
	static if((){
		version(Posix)     return true;
		else version(WASI) return true;
		else return false;
	}()){
		alias wchar_t = dchar;
	}else static if((){
		version (Windows) return true;
		else return false;
	}()){
		alias wchar_t = wchar;
	}else static assert(0, "`sizeof(wchar_t)` is not known on this platform. Please add it to bindbc/common/config.d, or update your compiler to a version based on dmd 2.101 or higher");
}
