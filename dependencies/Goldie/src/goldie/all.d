﻿// Goldie: GOLD Engine for D
// GoldieLib
// Written in the D programming language.
//
// Main GoldieLib import file.

//TODO: Encapsulate file(line:col) string generation
//TODO: Fix: error reporting for col of root token is wrong (-1 converted to unsigned?)

module /+S:PACKAGE+/goldie/+E:PACKAGE+/.all;

/// Note: goldie.file, goldie.grmc.* and goldie.langs.* are not imported here
/// because the vast majority of apps will not need to use them directly.

/+P:SET_VERSION+/
/+S:REM+/version = Goldie_DynamicStyle;/+E:REM+/

version(Goldie_StaticStyle)
version(DigitalMars)
{
	import std.compiler;
	static if(version_major == 2 && version_minor == 57)
		static assert(false, "Goldie's static-style and grammar compiling don't work on DMD 2.057 due to DMD Issue #7375");
}

version(Goldie_DynamicStyle)
{
	public import goldie.base;
	public import goldie.exception;
	public import goldie.lang;
	public import goldie.lexer;
	public import goldie.parser;
	public import goldie.token;
	public import goldie.ver;
}
else
{
	public import /+P:PACKAGE+/DUMMY.lang;
	public import /+P:PACKAGE+/DUMMY.lexer;
	public import /+P:PACKAGE+/DUMMY.parser;
	public import /+P:PACKAGE+/DUMMY.token;
	
	// Ensure Goldie versions match
	import goldie.ver;
	static if(goldieVerStr != "/+P:VERSION+/")
	{
		pragma(msg,
			"You're using Goldie v"~goldieVerStr~", but this static-style language "~
			"was generated with Goldie v/+P:VERSION+/. You must regenerate the langauge "~
			"with 'goldie-staticlang'."
		);
		static assert(false, "Mismatched Goldie versions");
	}
}

//TODO? Make sanity checks execute in debug-mode only
//TODO? Sanitize usages of terminology like "symbol", "token name" etc. in class Token
//TODO: Make modification of calculator* that builds an AST and saves as XML instead of calculating.
//TODO: Add StringOf to Token_{languageName}!() and Token
//TODO: Fix: Lexer_{languageName}.process() takes a Language as a parameter (Also 'Parser_').
//TODO: Check on incorrect line/col reported upon lexer error that spans
//      multiple lines and ends with EOL.
//TODO? Add skeleton "process" func in generated static-style.