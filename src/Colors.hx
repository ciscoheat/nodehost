/**
 * Use with "using js.npm.Colors" instead of import to get it as an extension to String.
 */ 
@:jsRequire('colors')
extern class Colors 
{
	public static function black(str : String) : String;
	public static function red(str : String) : String;
	public static function green(str : String) : String;
	public static function yellow(str : String) : String;
	public static function blue(str : String) : String;
	public static function magenta(str : String) : String;
	public static function cyan(str : String) : String;
	public static function white(str : String) : String;
	public static function gray(str : String) : String;
	public static function grey(str : String) : String;

	public static function bgBlack(str : String) : String;
	public static function bgRed(str : String) : String;
	public static function bgGreen(str : String) : String;
	public static function bgYellow(str : String) : String;
	public static function bgBlue(str : String) : String;
	public static function bgMagenta(str : String) : String;
	public static function bgCyan(str : String) : String;
	public static function bgWhite(str : String) : String;

	public static function reset(str : String) : String;
	public static function bold(str : String) : String;
	public static function dim(str : String) : String;
	public static function italic(str : String) : String;
	public static function underline(str : String) : String;
	public static function inverse(str : String) : String;
	public static function hidden(str : String) : String;
	public static function strikethrough(str : String) : String;
	public static function rainbow(str : String) : String;
	public static function zebra(str : String) : String;
	public static function america(str : String) : String;
	public static function trap(str : String) : String;
	public static function random(str : String) : String;
}
