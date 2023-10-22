package cube;

import sys.io.File;
import sys.FileSystem;

#if openfl
import openfl.utils.Assets as OpenFLAssets;
#end

class CubeUtils {
	/**
	 * Returns whether or not a specified file path exists.
	 * 
	 * @param path  The file path to check.
	 */
	public static function exists(path:String) {
		return #if openfl OpenFLAssets.exists(path) || #end FileSystem.exists(path);
	}

	/**
	 * Returns the text contents of a file from a given path.
	 * 
	 * @param path  The path to the file.
	 */
	public static function getText(path:String) {
		#if openfl
		if(OpenFLAssets.exists(path))
			return OpenFLAssets.getText(path);
		#end
		return FileSystem.exists(path) ? File.getContent(path) : "";
	}
}