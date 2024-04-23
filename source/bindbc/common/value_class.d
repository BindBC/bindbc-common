/+
+               Copyright 2024 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module bindbc.common.value_class;

struct ValueClass(T)
if(is(T == class)){
	void[__traits(classInstanceSize, T)] data;
	
	@disable this(); //default constructor initialises `data` to zeros, causing segfaults
	///Default constructor with a dummy parameter.
	this(int) nothrow @nogc pure @trusted{
		data[] = __traits(initSymbol, T);
	}
	///Copy data from an existing class instance.
	this(scope const T val) nothrow @nogc pure{
		data[] = *(cast(void[]*)&val);
	}
	
	alias get this;
	pragma(inline,true)
	T get() nothrow @nogc pure return scope =>
		cast(T)&data;
}
unittest{
	extern(C++) class A{
		uint x,y;
		void yarr(){}
	}
	extern(C++) class B: A{
		uint w,h;
	}
	auto boom(A a){
		return a.x + a.y;
	}
	alias V = ValueClass!B;
	
	V a = V(0);
	a.x = 15;
	a.y = 100;
	a.w = 59;
	a.h = 479;
	void[] b = cast(void[])((&a)[0..1]);
	V c = *cast(V*)b[0..V.sizeof];
	
	assert(boom(c) == 115);
}
