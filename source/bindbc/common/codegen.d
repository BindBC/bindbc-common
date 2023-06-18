/+
+            Copyright 2022 – 2023 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module bindbc.common.codegen;

enum mangleofCppDefaultCtor = (string sym) nothrow pure @safe{
	static if((){
		version(CppRuntime_Clang)    return true;
		else version(CppRuntime_Gcc) return true;
		else return false;
	}()){
		string len = "";
		size_t i = sym.length;
		while(i > 0){
			len = ('0' + (i % 10)) ~ len;
			i /= 10;
		}
		return "_ZN" ~ len ~ sym ~ "C1Ev";
	}else static if((){
		version(CppRuntime_Microsoft)        return true;
		else version(CppRuntime_DigitalMars) return true;
		else return false;
	}()){
		return "??0" ~ sym ~ "@@QAE@XZ";
	}else static assert(0, "Unknown runtime, not sure what mangling to use. Please check how your compiler mangles C++ struct constructors and add code for it to `bindbc.common.codegen.mangleofCppDefaultCtor`.");
};
unittest{
	static if((){
		version(CppRuntime_Clang)    return true;
		else version(CppRuntime_Gcc) return true;
		else return false;
	}()){
		static assert("ImGuiListClipper".mangleofCppDefaultCtor() == "_ZN16ImGuiListClipperC1Ev");
	}else static if((){
		version(CppRuntime_Microsoft)        return true;
		else version(CppRuntime_DigitalMars) return true;
		else return false;
	}()){
		static assert("ImGuiListClipper".mangleofCppDefaultCtor() == "??0ImGuiListClipper@@QAE@XZ");
	}
}

size_t badHash(string s) nothrow pure @safe{
	size_t ret = 0;
	for(size_t i = 0; i < s.length; i += 2){
		ret += s[i]; //yes, this is a *really* bad hashing algorithm!
	}

	return ret * s.length;
}

enum toStrCT = (size_t val) nothrow pure @safe{
	enum base = 10;
	
	if(!val) return "0";

	string ret;
	while(val > 0){
		ret = cast(char)('0' + (val % base)) ~ ret;
		val /= base;
	}
	return ret;
};

enum makeFnBindFns = (bool staticBinding) nothrow pure @safe{
	string ret = `
/*regex: function decl => makeFnBinds decl
^[ \t]*([A-Za-z0-9_()*\[\]]+) (\w+) ?\(([A-Za-z0-9_()*, .=\[\]]*)\);
\t\t[q{$1}, q{$2}, q{$3}],
*/
enum makeFnBinds = (string[][] fns) nothrow pure @safe{
	string makeFnBinds = "";`;
	if(staticBinding){
		ret ~= `
	foreach(fn; fns){
		if(fn.length == 3){ //C
			makeFnBinds ~= "\n\textern(C) ";
		}else if(fn.length == 4){ //C++ or Objective-C
			makeFnBinds ~= "\n\textern("~fn[3]~") ";
		}else assert(0, "Wrong number of function items");
		
		if(fn[1] == "this"){
			makeFnBinds ~= "pragma(mangle, mangleofCppDefaultCtor(__traits(identifier, typeof(this)))) this(int _);";
		}else{
			makeFnBinds ~= fn[0]~" "~fn[1]~"("~fn[2]~");";
		}
	}
	return [makeFnBinds];`;
	}else{
		ret ~= `
	string[] symbols;
	foreach(fn; fns){
		string prefix;
		string hash;
		if(fn.length == 3){ //C
			prefix = "\n\textern(C) ";
			hash = "";
		}else if(fn.length == 4){ //C++ or Objective-C
			prefix = "\n\textern("~fn[3]~") ";
			import bindbc.common.codegen: badHash, toStrCT;
			hash = badHash(fn[2]).toStrCT();
		}else assert(0, "Wrong number of function items");
		
		symbols ~= "_" ~ fn[1] ~ hash;

		if(fn[2].length > 3 && fn[2][$-3..$] == "..."){
			makeFnBinds ~= prefix~"package "~fn[0]~" function("~fn[2]~") _"~fn[1]~hash~";";
			makeFnBinds ~= "\n\talias "~fn[1]~" = _"~fn[1]~";";
		}else{
			makeFnBinds ~= prefix~"package "~fn[0]~" function("~fn[2]~") _"~fn[1]~hash~";";
			if(fn[1] == "this"){ //constructor
				if(fn[2] == ""){ //default constructor
					makeFnBinds ~= prefix~"pragma(mangle, mangleofCppDefaultCtor(__traits(identifier, typeof(this)))) this(int _){ _this"~hash~"(); }";
				}else{
					makeFnBinds ~= prefix~"this("~fn[2]~"){ _this"~hash~"(__traits(parameters)); }";
				}
			}else if(fn[0].length >= 4 && fn[0][$-4..$] == "void"){
				makeFnBinds ~= prefix~fn[0]~" "~fn[1]~"("~fn[2]~"){ _"~fn[1]~hash~"(__traits(parameters)); }";
			}else{
				makeFnBinds ~= prefix~fn[0]~" "~fn[1]~"("~fn[2]~"){ return _"~fn[1]~hash~"(__traits(parameters)); }";
			}
		}
	}
	return [makeFnBinds] ~ symbols;`;
	}
	ret ~= `
};

enum joinFnBinds = (string[][] list, bool bindMemberFns=false) nothrow pure @safe{`;
	if(staticBinding){
		ret ~= `
	string joined = "@nogc nothrow{";
	foreach(item; list){
		joined ~= item[0];
	}`;
	}else{
		ret ~= `
	string joined = "\n@nogc nothrow __gshared{";
	string[] symbols;
	foreach(item; list){
		joined ~= item[0];
		symbols ~= item[1..$];
	}`;
	}
	ret ~= `
	joined ~= "\n}";`;
	
	if(!staticBinding){
		ret ~= `
	joined ~= "\n\nimport bindbc.loader: SharedLib, bindSymbol;\nvoid bindModuleSymbols(SharedLib lib) @nogc nothrow{";
	foreach(symbol; symbols){
		joined ~= "\n\tlib.bindSymbol(cast(void**)&"~symbol~", "~symbol~".mangleof);";
	}
	if(bindMemberFns){
		joined ~= q{
		pragma(msg, "MODULE: "~__MODULE__);
		static foreach(member; __traits(allMembers, mixin(__MODULE__))){
			pragma(msg, member);
			static if( (is(mixin(member) == struct) || is(mixin(member) == class) || is(mixin(member) == struct)) && (__traits(getLinkage, mixin(member)) == "C++" || __traits(getLinkage, mixin(member)) == "Objective-C") ){
				mixin(member~".bindModuleSymbols();");
			}
		}
		};
	}
	joined ~= "\n}";`;
	}
	
	ret ~= `
	return joined;
};`;
	return ret;
};

enum makeExpandedEnum(Enum) = () nothrow pure @safe{
	string ret;
	foreach(member; __traits(allMembers, Enum)){
		ret ~= "\nenum "~member~" = "~Enum.stringof~"."~member~";";
	}
	return ret;
}();
