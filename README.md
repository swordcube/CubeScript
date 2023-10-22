<img src="https://raw.githubusercontent.com/swordcube/CubeScript/main/logo.png" alt="CubeScript Logo" align="right" width="200" height="200" />

# CubeScript
A simple to use wrapper for HScript.

## ❕ Getting Started
Let's start off with the basics of using CubeScript. Here are
some basic examples:

### 📜 Running a string
```haxe
var script = new CubeScript("trace('Hello CubeScript!');", {preset: true, unsafe: false});
script.start(); // The trace runs as soon as the script starts.
```

### 📜 Running a file
```haxe
var script = new CubeScript(File.getContent("myScript.hx"), {preset: true, unsafe: false});
script.start(); // The script's code runs as soon as the script starts.
```

### 📜 Running a function
```haxe
var script = new CubeScript("
	function test(arg1, arg2) {
		trace('The test works!');
		trace(arg1);
		trace(arg2);
	}
", {preset: true, unsafe: false});
script.start(); // The function gets initialized when the script starts.
script.call("test", ["This is an int -> ", 0]);
```