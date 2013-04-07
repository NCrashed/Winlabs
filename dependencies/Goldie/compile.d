#!/usr/bin/rdmd
/// Script for automatic building Goldie for Linux and Windows
module compile;

import dmake;

import std.stdio;
import std.process;

string[string] depends;

static this()
{
	depends["semitwist"] = "../SemiTwistDTools";
}

void compileSemiTwist(string libPath)
{
	system("cd "~libPath~" && rdmd compile.d all release");
}

//======================================================================
//							Main part
//======================================================================
int main(string[] args)
{
	// grmc
	addCompTarget("grmc", "./bin", "goldie-grmc", BUILD.APP);
	setDependPaths(depends);
	addSource("src/goldie");
	addSource("src/tools/grmc");
	addSingleFile("src/tools/util.d");
	addLibraryFiles("semitwist", "bin", ["semitwist"], ["src"], &compileSemiTwist);

	// staticlang
	addCompTarget("staticlang", "./bin", "goldie-staticlang", BUILD.APP);
	setDependPaths(depends);
	addSource("src/goldie");
	addSource("src/tools/staticlang");
	addSingleFile("src/tools/util.d");
	addLibraryFiles("semitwist", "bin", ["semitwist"], ["src"], &compileSemiTwist);

	// Lib for ThunderEngine
	addCompTarget("goldie", "./bin", "goldie", BUILD.LIB);
	setDependPaths(depends);
	addSource("src/goldie");
	addSingleFile("src/tools/util.d");
	addLibraryFiles("semitwist", "bin", ["semitwist"], ["src"], &compileSemiTwist);

	checkProgram("dmd", "Cannot find dmd to compile project! You can get it from http://dlang.org/download.html");
	// Компиляция!
	return proceedCmd(args);
}