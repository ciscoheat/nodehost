typedef GlobOptions = {
	?cwd : String,
	?root : String,
	?dot : Bool,
	?nomount : Bool,
	?mark : Bool,
	?nosort : Bool,
	?stat : Bool,
	?silent : Bool,
	?strict : Bool,
	?cache : Dynamic,
	?statCache : Dynamic,
	?symlinks : Dynamic,
	?nounique : Bool,
	?nonull : Bool,
	?debug : Bool,
	?nobrace : Bool,
	?noglobstar : Bool,
	?noext : Bool,
	?nocase : Bool,
	?matchBase : Bool,
	?nodir : Bool,
	?ignore : Dynamic,
	?follow : Bool,
	?realpath : Bool
}

@:jsRequire('glob') extern class Glob
{
	@:overload(function(pattern : String) : Bool {})
	public static function hasMagic(pattern : String, options : {?noext: Bool, ?nobrace: Bool}) : Bool;

	@:overload(function(pattern : String, options : Glob) : Array<String> {})
	@:overload(function(pattern : String, options : GlobOptions) : Array<String> {})
	public static function sync(pattern : String) : Array<String>;

	@:overload(function(pattern : String, options : Glob, cb : js.Error -> Array<String>) : Void {})
	@:overload(function(pattern : String, options : GlobOptions, cb : js.Error -> Array<String>) : Void {})
	@:selfCall public function new(pattern : String, cb : js.Error -> Array<String>) : Void;
}
