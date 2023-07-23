/+
+            Copyright 2022 – 2023 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module bindbc.common.codegen;

import bindbc.common.versions;

/**
Data for function bindings.

Only the locations of the first 3 fields (`retn`, `iden`, and `params`) should be
relied on. Every other field should always be written/read by using its identifier.
Example:
```d
FnBbind one = {q{void}, q{someCppFn}, q{int si, uint ui}, ext: `C++`}; //OK
FnBbind two = {q{void}, q{someCppFn}, q{uint ui, int si}, `C++`}; //`ext` was not specified by identifier; might break in the future!

Never place whitespace around strings provided to FnBind, as it may cause incorrect binding generation.
```
*/
struct FnBind{
	/**
	Return type.
	Passing `const char*` instead of '`const(char)*` to a member function will
	erroneously cause the function to be `const`. You should use `attrib` for this instead.
	Must be void for constructors and destructors.
	Must be non-null, except where it is ignored.
	*/
	string retn;
	
	/**
	The identifier of the function in the library you are binding.
	Use `this` when binding a constructor, `~this` when binding a destructor.
	Must be non-null.
	*/
	string iden; 
	
	/**
	Comma-separated named function parameters.
	Constructors can have no parameters. Constructors with all-default parameters will not currently work!
	
	
	Default: no parameters
	*/
	string params = "";
	
	/**
	Specifies which `extern` linkage to use.
	| Support status    | Input           | Generated code          |
	|-------------------|-----------------|-------------------------|
	| Fully supported   | `C`             | `extern(C)`             |
	| Mostly supported  | `C++`           | `extern(C++)`           |
	| Mostly supported  | `C++. "name"`   | `extern(C++, "name")`   |
	| Mostly supported  | `C++. "a", "b"` | `extern(C++, "a", "b")` |
	| Not yet supported | `Objective-C`   | `extern(Objective-C)`   |
	
	Default: C
	*/
	string ext = `C`;
	
	/**
	Optional: Function attributes.
	*/
	string attr;
	
	/**
	Optional: If populated, `iden` will be private and a public alias with the name `pubIden` will be created.
	*/
	string pubIden;
	
	/**
	Optional: Member function attributes.
	*/
	string memAttr;
	
	/**
	Optional:
	Anything to be placed immediately before the public version of the function, like `deprecated`, etc.
	*/
	string pfix;
	
	/**
	Optional: A list of identifiers to be aliases of the function.
	*/
	string[] aliases;
}

/**
Returns: A mixin string with code for creating function bindings.

Params:
	staticBinding = Whether the functions generate static bindings, or otherwise dynamic ones.
	version = The version of BindBC-Common that your code is written for.
*/
enum makeFnBindFns = (bool staticBinding, Version version_=Version(0,1,0)) nothrow pure @safe{
	if(version_ >= Version(0,1,1) && version_ <= bindBCCommonVersion){
		return
"alias joinFnBinds = bindbc.common.codegen.joinFnBinds!" ~ (staticBinding ? "true" : "false") ~ ";
alias FnBind = bindbc.common.codegen.FnBind;";
	}else if(version_ == Version(0,1,0)){
		return
"import bindbc.common.legacy.v0_1_0: makeFnBindsProto, joinFnBindsProto;
alias makeFnBinds = makeFnBindsProto;
alias joinFnBinds = joinFnBindsProto!" ~ (staticBinding ? "true" : "false") ~ ";";
	}else assert(0, "Invalid version supplied.");
};

enum joinFnBinds(bool staticBinding) = (FnBind[] fns, string membersWithFns=null) nothrow pure @safe{
	string ret;
	
	static if(staticBinding){
		ret ~= "nothrow @nogc{\n";
		foreach(fn; fns){
			string pfix = (fn.pfix.length ? fn.pfix~" " : "") ~ (fn.pubIden.length ? "package " : "") ~ "extern("~fn.ext~") ";
			if(fn.iden == "this"){
				if(fn.params.length){
					ret ~= "\t" ~ pfix ~ "this("~fn.params~")" ~ (fn.memAttr.length ? " "~fn.memAttr : "") ~ ";\n";
				}else{
					ret ~= "\t\timport bindbc.common.codegen: mangleofCppDefaultCtor;\n";
					ret ~= "\t" ~ pfix ~ "pragma(mangle, [__traits(getCppNamespaces, typeof(this)), __traits(identifier, typeof(this))].mangleofCppDefaultCtor()) this(int _)" ~ (fn.memAttr.length ? " "~fn.memAttr : "") ~ ";\n";
				}
			}else{
				ret ~= "\t" ~ pfix ~ fn.retn ~ " " ~ fn.iden ~ "("~fn.params~")" ~ (fn.memAttr.length ? " "~fn.memAttr : "") ~ ";\n";
			}
			
			if(fn.pubIden.length){
				ret ~= "\talias " ~ fn.pubIden ~ " = " ~ fn.iden ~ ";\n";
			}
			foreach(alias_; fn.aliases){
				ret ~= "\talias " ~ alias_ ~ " = " ~ fn.iden ~ ";\n";
			}
		}
		ret ~= "}";
	}else{
		ret ~= "__gshared nothrow @nogc{\n";
		
		string dyn =
`import bindbc.loader: SharedLib, bindSymbol;
static void bindModuleSymbols(SharedLib lib) nothrow @nogc{
	alias here = ` ~ makeOuterScope() ~ `; import std.stdio; debug writeln(here.stringof);`;
		
		//Helps us see if functions have overloads.
		uint[string] usedIdens;
		foreach(fn; fns){
			if(fn.ext != "C"){ //Could this function have overloads?
				if(auto num = fn.iden in usedIdens){
					(*num) = 1;
				}else{
					usedIdens[fn.iden] = 0;
				}
			}
		}
		
		foreach(fn; fns){
			//Are there overloads of this function?
			uint overload = 0;
			if(fn.ext != "C"){
				if(auto num = fn.iden in usedIdens){
					overload = *num;
					(*num)++;
				}
			}
			
			string ext = "extern("~fn.ext~") ";
			string pfix = (fn.pfix.length ? fn.pfix~" " : "") ~ (fn.pubIden.length ? "package " : "") ~ ext; 
			
			//Is this a variadic function?
			bool variadic = fn.params.length > 3 && fn.params[$-3..$] == "...";
			//Is this a member function?
			bool memberFn = membersWithFns is null && fn.ext != "C";
			
			//`iden` is either the identifier for this function, or an internal name if the function identifier is special (e.g. `this`)
			string iden = (){
				switch(fn.iden){
					case "this": return "__ctor";
					case "~this": return "__dtor";
					default: return fn.iden;
				}
			}();
			//Whether a special identifier (`__ctor`/`__dtor`) is in-use.
			//bool specialIden = iden != fn.iden;
			
			//The function pointer's parameters, and how to call it from the public function.
			string ptrParams = fn.params;
			string ptrCall = "__traits(parameters)";
			if(memberFn){
				if(fn.params.length){
					ptrParams = "ref inout(typeof(this)) this_, " ~ ptrParams;
					ptrCall = "this, " ~ ptrCall;
				}else{
					ptrParams = "ref inout(typeof(this)) this_";
					ptrCall = "this";
				}
				ptrParams = (fn.memAttr.length ? fn.memAttr~" " : "") ~ ptrParams;
			}
			
			if(variadic && !overload){
				ret ~= "\t" ~ ext ~ fn.retn ~ " function(" ~ ptrParams ~ ") " ~ iden ~ ";\n";
			}
			
			string ptrIden = "_"~fn.iden;
			if(overload){
				string overloadStr = overload.toStrCT();
				ptrIden ~= overloadStr;
				//if(!specialIden){
					//iden ~= "_"~overloadStr;
					//pfix = "package " ~ pfix;
				//}
			}
			
			ptrCall = ptrIden ~ "("~ptrCall~");";
			
			
			if(overload){
				dyn ~= `
	{
		alias FnCmp = void(`~fn.params~`);
		static if(is(FnCmp ArgsCmp == function)){
			static foreach(Fn; __traits(getOverloads, here, "` ~ iden ~ `")){{
				static if(is(typeof(Fn) Args == function)){
					static if(is(Args == ArgsCmp)){
						lib.bindSymbol(cast(void**)&` ~ ptrIden ~ `, Fn.mangleof);
					}
				}else static assert(0);
			}}
		}else static assert(0);
	}`;
			}else if(variadic){
				dyn ~= `
	lib.bindSymbol(cast(void**)&` ~ iden ~ `, here.` ~ iden ~ `.mangleof);`;
				continue;
			}else{
				dyn ~= `
	lib.bindSymbol(cast(void**)&` ~ ptrIden ~ `, here.` ~ iden ~ `.mangleof);`;
				
			}
			
			//Private function pointer declaration.
			ret ~= "\tpackage " ~ ext ~ fn.retn ~ " function(" ~ ptrParams ~ ") " ~ ptrIden ~ ";\n";
			
			string fnParams = fn.params;
			if(variadic && overload){
				fnParams = "T...)("~fnParams[0..$-3]~"T _variadics";
			}
			if(fn.iden == "this"){ //Constructor.
				if(fn.params.length){
					//TODO: Check if the parameters are all defaults here :(
					ret ~= "\t" ~ pfix ~ "this("~fnParams~")" ~ (fn.memAttr.length ? " "~fn.memAttr : "") ~ "{ " ~ ptrCall ~ " }\n";
				}else if(fn.ext.length >= 3 && fn.ext[0..3] == "C++"){ //Default constructor; must have no parameters.
					ret ~= "\timport bindbc.common.codegen: mangleofCppDefaultCtor;\n";
					ret ~= "\t" ~ pfix ~ "pragma(mangle, [__traits(getCppNamespaces, typeof(this)), __traits(identifier, typeof(this))].mangleofCppDefaultCtor()) this(int _)" ~ (fn.memAttr.length ? " "~fn.memAttr : "") ~ "{ " ~ ptrCall ~ " }\n";
				}else assert(0, "Default constructor mangling for extern("~fn.ext~") is unknown.");
			}else if(fn.iden == "~this"){ //Destructor.
				ret ~= "\t" ~ pfix ~ "~this("~fnParams~")" ~ (fn.memAttr.length ? " "~fn.memAttr : "") ~ "{ " ~ ptrCall ~ " }\n";
			}else{
				if(fn.retn != "void"){
					ptrCall = "return " ~ ptrCall;
				}
				ret ~= "\t" ~ pfix ~ fn.retn ~ " " ~ fn.iden ~ "("~fnParams~")" ~ (fn.memAttr.length ? " "~fn.memAttr : "") ~ "{ " ~ ptrCall ~ " }\n";
			}
			
			if(fn.pubIden.length){
				ret ~= "\talias " ~ fn.pubIden ~ " = " ~ iden ~ ";\n";
			}
			foreach(alias_; fn.aliases){
				ret ~= "\talias " ~ alias_ ~ " = " ~ iden ~ ";"; 
			}
		}
		
		if(membersWithFns.length){
			//This method is easier to rewrite to use __traits(allMembers) later
			dyn ~= `
	alias AliasSeq(T...) = T;
	static foreach(item; AliasSeq!(` ~ membersWithFns ~ `)){ 
		static assert((is(item == struct) || is(item == class)) && (__traits(getLinkage, item) == "C++" || __traits(getLinkage, item) == "Objective-C") && __traits(hasMember, item, "bindModuleSymbols"));
		mixin(item,".bindModuleSymbols(lib);");
	}`;
		}
		
		ret ~= "}\n\n" ~ dyn ~ "\n}";
	}
	return ret;
};

/*//TODO: some time after __traits(allMembers) is fixed, remove "membersWithFns" and check over each type it returns automatically! :)
enum joinFnBinds = (string[][] list, string membersWithFns="") nothrow pure @safe{;
	static if(staticBinding){
		string joined = "{";
	}else{ 
	string joined = "\n@nogc nothrow __gshared{";;
	}
	foreach(item; list){
		joined ~= item[0];
	}
	joined ~= "\n}";;
	
	static if(!staticBinding){
	joined ~= "\n\nimport bindbc.loader: SharedLib, bindSymbol;\nstatic void bindModuleSymbols(SharedLib lib) @nogc nothrow{";
	foreach(item; list){
		if(item[2] == "this") item[2] = "__ctor";
		if(item[3].length > 0){
			joined ~= "
	static if("~((item[3].length > 3 && item[3][$-3..$] == "...") ? "true" : "false")~" || __traits(getOverloads, "~outerScope~", \""~item[2]~"\").length > 0){
		static foreach(Fn; __traits(getOverloads, "~outerScope~", \""~item[2]~"\")){
			{
				void Fn2("~item[3]~"){}
				static if(is(typeof(Fn) Args1 == __parameters) && is(typeof(Fn2) Args2 == __parameters)){
					static if(is(Args1 == Args2)){
						lib.bindSymbol(cast(void**)&"~item[1]~", Fn.mangleof);
					}
				}else static assert(0);
			}
		}
	}else{
		lib.bindSymbol(cast(void**)&"~item[1]~", "~outerScope~"."~item[2]~".mangleof);
	}";
		}else{
			joined ~= "\n\tlib.bindSymbol(cast(void**)&"~item[1]~", "~outerScope~"."~item[2]~".mangleof);";
		}
	}
	if(membersWithFns.length > 0){
		joined ~= q{
		alias AliasSeq(T...) = T;
		static foreach(member; AliasSeq!(}~membersWithFns~q{)){
			static if( (is(member == struct) || is(member == class) || is(member == struct)) && (__traits(getLinkage, member) == "C++" || __traits(getLinkage, member) == "Objective-C") ){
				mixin(member,".bindModuleSymbols(lib);");
			}
		}
		};
	}
	joined ~= "\n}";;
	}
	
	return joined;
};*/

///For internal use only.
enum makeIsMember = () nothrow pure @safe{
	return "__traits(compiles, typeof(this))";
};
unittest{
	static assert(mixin(makeIsMember()) == false);
	struct XXX{
		static assert(mixin(makeIsMember()) == true);
	}
}

///For internal use only.
package enum makeOuterScope = () nothrow pure @safe{
	return
"mixin((string mod=__MODULE__){
	static if(__traits(compiles, typeof(this))) return __traits(identifier, typeof(this));
	else return mod;
}())";
};
unittest{
	static assert(__traits(isSame, mixin(makeOuterScope()), bindbc.common.codegen));
	struct XXX{
		static assert(is(mixin(makeOuterScope()) == XXX));
	}
}

///For internal use only.
enum mangleofCppDefaultCtor = (string[] syms) nothrow pure @safe{
	static if((){
		version(CppRuntime_Clang)    return true;
		else version(CppRuntime_Gcc) return true;
		else return false;
	}()){
		string ret = "_ZN";
		foreach(sym; syms){
			ret ~= toStrCT(sym.length) ~ sym;
		}
		return  ret ~ "C1Ev";
	}else static if((){
		version(CppRuntime_Microsoft)        return true;
		else version(CppRuntime_DigitalMars) return true;
		else return false;
	}()){
		string ret = "??0";
		foreach(sym; syms){
			ret ~= sym ~ "@";
		}
		version(D_X32){
			return ret ~ "@QAE@XZ";
		}else{
			return ret ~ "@QEAA@XZ";
		}
	}else static assert(0, "Unknown runtime, not sure what mangling to use. Please check how your compiler mangles C++ struct constructors and add a case for it to `bindbc.common.codegen.mangleofCppDefaultCtor`.");
};
unittest{
	static if((){
		version(CppRuntime_Clang)    return true;
		else version(CppRuntime_Gcc) return true;
		else return false;
	}()){
		static assert(["ImGuiListClipper"].mangleofCppDefaultCtor() == "_ZN16ImGuiListClipperC1Ev");
		static assert(["bgfx", "Init"].mangleofCppDefaultCtor() == "_ZN4bgfx4InitC1Ev");
	}else static if((){
		version(CppRuntime_Microsoft)        return true;
		else version(CppRuntime_DigitalMars) return true;
		else return false;
	}()){
		version(D_X32){
			static assert(["ImGuiListClipper"].mangleofCppDefaultCtor() == "??0ImGuiListClipper@@QAE@XZ");
			static assert(["bgfx", "Init"].mangleofCppDefaultCtor() == "??0Init@bgfx@@QAE@XZ");
		}else{
			static assert(["ImGuiListClipper"].mangleofCppDefaultCtor() == "??0ImGuiListClipper@@QEAA@XZ");
			static assert(["bgfx", "Init"].mangleofCppDefaultCtor() == "??0Init@bgfx@@QEAA@XZ");
		}
	}else static assert(0);
}

///For internal use only.
size_t badHash(string s) nothrow pure @safe{
	size_t ret = 0;
	for(size_t i = 0; i < s.length; i += 2){
		ret += s[i]; //yes, this is a *really* bad hashing algorithm!
	}
	return ret * s.length;
}
unittest{
	static assert(badHash("const(void)* ptr") != badHash("char alpha"));
	static assert(badHash("const(void)* ptr") != badHash("const(void)* chr"));
	static assert(badHash("ubyte id, size_t ind, char* buf") != badHash("wchar utf16, char* utf8"));
	static assert(badHash("dchar utf16, char* utf8, bool er") != badHash("wchar utf16, char* utf8, bool er"));
}

///For internal use only.
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
unittest{
	static assert(0.toStrCT() == "0");
	static assert(4.toStrCT() == "4");
	static assert(120.toStrCT() == "120");
	static assert(589_000.toStrCT() == "589000");
	static assert(9_396_460_865_079_328.toStrCT() == "9396460865079328");
	static assert(1_046_259_925_731_862_221.toStrCT() == "1046259925731862221");
}

/**
A workaround that BindBC used to use for C-style enums.
It is included here mostly for preservation.
*/
enum makeExpandedEnum(Enum) = () nothrow pure @safe{
	string ret;
	foreach(member; __traits(allMembers, Enum)){
		ret ~= "\nenum "~member~" = "~Enum.stringof~"."~member~";";
	}
	return ret;
}();
