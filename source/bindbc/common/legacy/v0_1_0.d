/+
+            Copyright 2022 – 2023 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module bindbc.common.legacy.v0_1_0;

//codegen.d
import codegen = bindbc.common.codegen;

/*
regex: function decl => makeFnBinds decl
[ \t]*([A-Za-z0-9_()*]+) (\w+) ?\(([A-Za-z0-9_()*, .=\"\-+%]*)\);
\t\t[q{$1}, q{$2}, q{$3}],
*/
///This function only exists for internal backwards-compatibility and should not be used by new libraries.
enum makeFnBindsProto = (string[][] fns, bool isMemberFn=false) nothrow pure @safe{
	string[][] ret;
	foreach(fn; fns){
		ret ~= [(){
			switch(fn.length){
				case 3:	
					return "{q{"~fn[0]~"}, q{"~fn[1]~"}, q{"~fn[2]~"}}";
				case 4:
					return "{q{"~fn[0]~"}, q{"~fn[1]~"}, q{"~fn[2]~"}, ext: `"~fn[3]~"`}";
				case 5:
					return "{q{"~fn[0]~"}, q{"~fn[1]~"}, q{"~fn[2]~"}, ext: `"~fn[3]~"`, memAttr: q{"~fn[4]~"}}";
				default: assert(0);
			}
		}()];
	}
	//if(ret.length) ret[0] ~= [isMemberFn ? "true" : "false"];
	return ret;
};

///This function only exists for internal backwards-compatibility and should not be used by new libraries.
enum joinFnBindsProto(bool staticBinding) = (string[][] list, string outerScope="", string membersWithFns="") nothrow pure @safe{
	string ret = "import bindbc.common.codegen: _bindbc_common_codegen_joinFnBinds = joinFnBinds;\n";
	ret ~= "mixin(_bindbc_common_codegen_joinFnBinds!" ~ (staticBinding ? "true" : "false") ~ "((){\n";
	ret ~= "\timport bindbc.common.codegen: FnBind;\n";
	ret ~= "\tFnBind[] ret = [\n";
	
	foreach(item; list){
		ret ~= "\t\t"~item[0]~",\n";
	}
	ret ~= "\t];\n";
	ret ~= "\treturn ret;\n";
	ret ~= "}(), `" ~ membersWithFns ~ "`));"; //list[0][1] = isMemberFn
	return ret;
};
unittest{
	import bindbc.common.codegen: makeFnBindFns;
	mixin(makeFnBindFns(true));
	static assert(joinFnBinds((){
		string[][] ret;
		ret ~= makeFnBinds([
			[q{void}, q{this}, q{}, `C++`],
		]);
		if(true){
			ret ~= makeFnBinds([
				[q{void}, q{notThis1}, q{int one}, `C++`],
			]);
		}
		if(true){
			ret ~= makeFnBinds([
				[q{void}, q{notThis2}, q{uint two}, `C++`, q{const}],
			]);
		}
		return ret;
	}(), __MODULE__) == "import bindbc.common.codegen: _bindbc_common_codegen_joinFnBinds = joinFnBinds;
mixin(_bindbc_common_codegen_joinFnBinds!true((){
	import bindbc.common.codegen: FnBind;
	FnBind[] ret = [
		{q{void}, q{this}, q{}, ext: `C++`},
		{q{void}, q{notThis1}, q{int one}, ext: `C++`},
		{q{void}, q{notThis2}, q{uint two}, ext: `C++`, memAttr: q{const}},
	];
	return ret;
}(), ``));");
}