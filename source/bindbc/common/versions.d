/+
+            Copyright 2023 – 2024 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module bindbc.common.versions;

struct Version{
	int major;
	int minor;
	int patch;
	
	enum none = Version(int.min, 0, 0);
	enum bad = Version(-1, 0, 0);
	
	int opCmp(Version x) const nothrow @nogc pure @safe{
		if(major != x.major){
			return major - x.major;
		}else if(minor != x.minor){
			return minor - x.minor;
		}else{
			return patch - x.patch;
		}
	}
	unittest{
		assert(Version(0,1,0) > Version(0,0,57));
		assert(Version(0,4,0) == Version(0,4,0));
		assert(Version(0,40,80) < Version(1,0,0));
	}
	
	Version opBinary(string op: "+")(Version rhs) const nothrow @nogc pure @safe
	in(rhs.major >= 0 && rhs.minor >= 0 && rhs.patch >= 0, "Cannot perform addition with negative version numbers."){
		if(rhs.major > 0){
			return Version(major + rhs.major, rhs.minor, rhs.patch);
		}else if(rhs.minor > 0){
			return Version(major, minor + rhs.minor, rhs.patch);
		}else{
			return Version(major, minor, patch + rhs.patch);
		}
	}
	unittest{
		assert(Version(0,5,7) + Version(0,1,0) == Version(0,6,0));
		assert(Version(0,5,7) + Version(0,1,1) == Version(0,6,1));
		assert(Version(1,5,7) + Version(1,0,0) == Version(2,0,0));
		assert(Version(1,5,7) + Version(1,3,4) == Version(2,3,4));
	}
	
	bool opCast(T: bool)() const nothrow @nogc pure @safe{
		return this != none && this != bad;
	}
}

///The current package version.
package enum bindBCCommonVersion = Version(1,0,0);
