#!/usr/bin/rdmd
module compile;

import dmake;

import std.stdio;
import std.process;
import std.file;

string[string] lab4Depends;
string[string] hometaskDepends;

static string[] getVCIncludes()
{
	return [
		`C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\Include`,
		`C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\include`,
		`C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\atlmfc\include`,
	];
} 

static this()
{
	lab4Depends =
	[
		"Winapi": "..",
		"Goldie": "../dependencies/Goldie",
		"SemiTwistDTools": "../dependencies/SemiTwistDTools",
	];

	hometaskDepends =
	[
		"Winapi": "..",
		"Goldie": "../dependencies/Goldie",
		"SemiTwistDTools": "../dependencies/SemiTwistDTools",
	];
}

void compileGoldie(string libPath)
{
	writeln("Building Goldie...");
	system("cd "~libPath~" && rdmd compile.d grmc release");
	system("cd "~libPath~" && rdmd compile.d staticlang release");
	system("cd "~libPath~" && rdmd compile.d goldie debug");
}

void compileSemiTwistDTools(string libPath)
{
	writeln("Building SemiTwistDTools...");
	system("cd "~libPath~" && rdmd compile.d all release");
}

void compileWin32Bindings(string libPath)
{
	writeln("Building winapi bindings...");
	system("rdmd compileWinapi.d all debug");
}

string compileGrammar()
{
	if(!exists("../src/hometask/expr.cgt") || !exists("../src/hometask/exprparser"))
	{
		return "cd ..\\src\\hometask && echo Building grammar... && ..\\..\\Dependencies\\Goldie\\bin\\goldie-grmc expr.grm && ..\\..\\Dependencies\\Goldie\\bin\\goldie-staticlang expr.cgt --pack=exprparser";
	}
	return "";
}

static string generateInclude(string[] paths)
{
	string ret;
	foreach(s; paths)
		ret~= `-I"`~s~`" `;
	return ret;
}
enum vcincludesCompiled = generateInclude(getVCIncludes());

string compileLab4Resources()
{
	return `rcc -32 -D_WIN32 `~vcincludesCompiled~` ..\src\lab4\lab4.rc -o..\bin\lab4.res && cd ..\src\lab4 && htod resource.h`;
}

string compileHometaskResources()
{
	return `rcc -32 -D_WIN32 `~vcincludesCompiled~` ..\src\hometask\hometask.rc -o..\bin\hometask.res && cd ..\src\hometask && htod resource.h`;
}

void cleanupParser()
{
	if(exists("../src/hometask/exprparser") && !exists("../src/hometask/expr.cgt"))
	{
		writeln("Removing old parser...");
		system("del /q ..\\src\\hometask\\exprparser");
	}
}

//======================================================================
//							Основная часть
//======================================================================
int main(string[] args)
{
	// Cleaning
	cleanupParser();

	// Lab4
	addCompTarget("lab4", "../bin", "lab4", BUILD.APP);
	setDependPaths(lab4Depends);

	addLibraryFiles("Winapi", "lib", ["dmd_win32_x32"], ["src"], &compileWin32Bindings);
	addLibraryFiles("SemiTwistDTools", "bin", ["semitwist"], ["src"], &compileSemiTwistDTools);
	addLibraryFiles("Goldie", "bin", ["goldie"], ["src"], &compileGoldie);

	addCustomCommand(&compileLab4Resources);
	addSource("../src/lab4");
	addCustomFlags("-version=Unicode -version=WindowsXP ../bin/lab4.res -version=VAR_8");

	// Hometask
	addCompTarget("hometask", "../bin", "hometask", BUILD.APP);
	setDependPaths(hometaskDepends);

	addLibraryFiles("Winapi", "lib", ["dmd_win32_x32"], ["src"], &compileWin32Bindings);
	addLibraryFiles("SemiTwistDTools", "bin", ["semitwist"], ["src"], &compileSemiTwistDTools);
	addLibraryFiles("Goldie", "bin", ["goldie"], ["src"], &compileGoldie);

	addCustomCommand(&compileGrammar);
	addCustomCommand(&compileHometaskResources);
	addGeneratedSources("../src/hometask/exprparser");
	addSource("../src/hometask");
	addCustomFlags("-version=Unicode -version=WindowsXP ../bin/hometask.res");

	checkProgram("dmd", "Cannot find dmd to compile project! You can get it from http://dlang.org/download.html");
	// Compilation
	return proceedCmd(args);
}