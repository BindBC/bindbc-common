/+
+                Copyright 2023 Aya Partridge
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
	
	int opCmp(Version x) @nogc nothrow pure{
		if(major != x.major)
			return major - x.major;
		else if(minor != x.minor)
			return minor - x.minor;
		else
			return patch - x.patch;
	}
}
