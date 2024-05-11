package cube;

import haxe.io.Path;

import hscript.Expr;
import hscript.Parser;
import hscript.Interp;

using StringTools;

typedef ScriptInitFlags = {
	/**
	 * Whether or not to have a bunch of preset
	 * variables for this script, to avoid mass-amounts of importing.
	 */
	@:optional var preset:Bool;

	 /**
	  * Whether or not to allow unsafe classes to be imported.
	  */
	@:optional var unsafe:Bool;
}
typedef FunctionCall = {
	/**
	 * The value that this function returned
	 * when being called.
	 */
	var value:Dynamic;
	 
	/**
	 * The error that occured when calling
	 * the function as a string.
	 * 
	 * Returns "Success" if no errors occured.
	 */
	var error:String;
}
typedef TraceFunction = Dynamic;

class CubeScript {
	/**
	 * The current version of CubeScript. [READ ONLY]
	 */
	public static var version(default, never):VersionScheme = {major: 0, minor: 2, patch: 0};

	/**
	 * Whether or not this script was destroyed.
	 */
	public var destroyed:Bool = false;

	/**
	 * The file name of the script.
	 */
	public var fileName:String;

	/**
	 * The file path of the script.
	 */
	public var filePath:String;

	/**
	 * The code this script runs when `start()` is called.
	 */
	public var code:String;

	/**
	 * Allows unsafe classes to be imported such as:
	 * - Sys
	 * - File
	 * - FileSystem
	 * - Process
	 * - Reflect
	 */
	public var unsafe(default, set):Bool;

	/**
	 * The trace function for this script.
	 * Can be easily overriden.
	 */
	public var trace(get, set):TraceFunction;

	/**
	 * Returns a new CubeScript.
	 * 
	 * @param file       The path to the file to load or the file's text contents.
	 * @param initFlags  Some flags to set before the script runs, such as `preset`, `unsafe`, etc.  
	 */
	public function new(file:String, ?initFlags:ScriptInitFlags) {
		if(initFlags == null) initFlags = {};

		final isFile:Bool = CubeUtils.exists(file);
		if(isFile) {
			filePath = file;
			fileName = Path.withoutDirectory(file);
			code = CubeUtils.getText(file).trim();
		} else {
			filePath = null;
			fileName = "CubeScript";
			code = file.trim();
		}
		if(code == null || code.length == 0) {
			code = "var empty = 0;"; // fixes a hscript-improved crash for empty scripts
		}

		interp = new Interp();
		this.unsafe = initFlags.unsafe ?? false;

		parser = new Parser();
		parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;

		this.trace = Reflect.makeVarArgs((data:Array<Dynamic>) -> {
			final posInfo = interp.posInfos();
			Sys.println('${fileName}:${posInfo.lineNumber}: ${Std.string(data)}');
		});

		final doPreset:Bool = initFlags.preset ?? true;
		if(doPreset) preset();
	}

	/**
	 * Starts the script.
	 */
	public function start() {
		if(destroyed) return {value: null, error: "Script was destroyed."};
		try {
			expr = parser.parseString(code, fileName);
			interp.execute(expr);
			return {value: this, error: "Success"};
		} catch (e:Error) {
			expr = null;
			_errorHandler(e);
			return {value: this, error: e.toString()};
		} catch (e) {
			expr = null;
			final msg:String = e.toString();
			_errorHandler(new Error(ECustom(msg), 0, 0, fileName, 0));
			return {value: this, error: msg};
		}
	}

	/**
	 * Returns the value of a given variable from the script.
	 * 
	 * @param variable  The name of the variable.
	 */
	public function get(variable:String) {
		return (!destroyed) ? interp.variables.get(variable) : null;
	}

	/**
	 * Sets the value of a given variable from the script to a given value.
	 * 
	 * @param variable  The name of the variable.
	 * @param value     The new value of the variable.
	 */
	public function set(variable:String, value:Dynamic) {
		if(destroyed) return;
		if(!unsafe && interp.importBlocklist.contains(variable)) {
			final posInfo = interp.posInfos();
			Sys.println('${fileName}:${posInfo.lineNumber}: ${variable} is an unsafe variable and cannot be imported!');
			return;
		}
		interp.variables.set(variable, value);
	}

	/**
	 * Imports a given class into the script.
	 * If this doesn't work, try using `setAbstract()` or `set()`.
	 * 
	 * @param cl  The class to import.
	 */
	public function setClass(cl:Class<Dynamic>) {
		final cln:String = Type.getClassName(cl);
		final i:Int = cln.lastIndexOf(".") + 1;
		set(cln.substr(i, cln.length), cl);
	}

	/**
	 * Imports a given abstract into the script.
	 * 
	 * @param ab  The path to abstract to import. (Ex: "example.proj.MyAbstract")
	 */
	public function setAbstract(ab:String) {
		final abn:String = ab.substr(ab.lastIndexOf(".") + 1, ab.length);
		final c = Type.resolveClass(ab);
		final chsc = Type.resolveClass('${ab}_HSC');
		set(abn, (c != null) ? c : chsc);
	}

	/**
	 * Calls a method/function in the script and returns
	 * whatever said method returns.
	 * 
	 * @param method      The name of the method to call.
	 * @param parameters  The parameters to supply to the method.
	 * 
	 * @return The return value of the method and the error that occured when calling the method.
	 */
	public function call(method:String, ?parameters:Array<Dynamic>):FunctionCall {
		if(parameters == null) parameters = [];
		try {
			var retValue:Dynamic = null;
			final func:Dynamic = get(method);
			if(func != null)
				retValue = Reflect.callMethod(null, func, parameters);
			return {value: retValue, error: 'Success'};
		} catch(e:Error) {
			_errorHandler(e);
			return {value: null, error: 'Failure - ${e}'};
		} catch(e) {
			final posInfos = interp.posInfos();
			_errorHandler(new Error(ECustom(e.toString()), 0, 0, fileName, posInfos.lineNumber));
			return {value: null, error: 'Failure - ${e}'};
		}
		return {value: null, error: "Success"};
	}

	/**
	 * Sets up a bunch of imports before this script starts,
	 * preventing imports cluttering up your scripts.
	 * 
	 * Override to add your own imports.
	 * Remember to call `super.preset()` when overriding this function!
	 */
	public function preset() {
		set("this", this);
		if(unsafe) {
			setClass(Sys);
			setClass(sys.io.File);
			setClass(sys.FileSystem);
			setClass(sys.io.Process);
			setClass(Reflect);
		}
		setClass(CubeScript);
		setClass(Date);
		setClass(DateTools);
		setClass(Math);
		setClass(Std);
		setClass(Array);
		set("Int", Int);
		set("Float", Float);
		set("Dynamic", Dynamic);
		setClass(StringTools);
		setClass(Type);
		#if openfl
		setClass(openfl.utils.Assets);
		#end
		setPreprocessorValue("CubeScript", true);
	}

	/**
	 * Sets a pre-processor value in the script.
	 * 
	 * Allows you to do #if, #else, and #elseif in scripts.
	 * 
	 * ### Example:
	 * ```haxe
	 * #if (name == "hi")
	 * trace('Name is equal to "hi".');
	 * #end
	 * ```
	 * 
	 * @param name   The name of the pre-processor to set.
	 * @param value  The value to set the pre-processor to.
	 */
	public function setPreprocessorValue(name:String, value:Dynamic) {
		parser.preprocesorValues.set(name, value);
	}

	/**
	 * Sets the object used to check variables if they
	 * don't exist within this script.
	 * 
	 * @param obj  The new script object.
	 */
	public function setScriptObject(obj:Dynamic) {
		if(destroyed) return;
		interp.scriptObject = obj;
	}

	/**
	 * Destroys this script and all of it's variables.
	 * 
	 * Trying to use this script after it has been destroyed could
	 * result in a crash!
	 */
	public function destroy() {
		if(destroyed == (destroyed = true))
			return;

		expr = null;
		parser = null;
		interp.scriptObject = null;
		interp = null;
	}

	//##==-----------------------------------------------==##//
	private var interp:Interp;
	private var parser:Parser;
	private var expr:Expr;

	@:noCompletion
	private inline function set_unsafe(value:Bool):Bool {
		if(!destroyed) {
			interp.importBlocklist = (value) ? [
				"Sys",
				"sys.io.File",
				"sys.FileSystem",
				"sys.io.Process",
				"Reflect"
			] : [];
		}
		return unsafe = value;
	}

	@:noCompletion
	private inline function set_trace(value:TraceFunction):TraceFunction {
		if(destroyed)
			interp.variables.set("trace", value);

		return value;
	}

	@:noCompletion
	private inline function get_trace():TraceFunction {
		return (!destroyed) ? interp.variables.get("trace") : null;
	}

	@:noCompletion
	private inline function _errorHandler(error:Error) {
		final fn = '${fileName}:${error.line}: ';
		var err = error.toString();
		if (err.startsWith(fn))
			err = err.substr(fn.length);
		Sys.println(err);
	}
}

@:structInit
class VersionScheme {
	public var major:Int;
	public var minor:Int;
	public var patch:Int = 0;

	/**
	 * Returns a string formatted like semantic versioning.
	 */
	public function toString() {
		return '${major}.${minor}.${patch}';
	}
}
