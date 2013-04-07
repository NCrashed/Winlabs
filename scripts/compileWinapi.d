#!/usr/bin/rdmd
module compile;

import dmake; 
import std.process;

//======================================================================
//							Основная часть
//======================================================================
int main(string[] args)
{
	// winapi
	addCompTarget("winapi", "../lib", "dmd_win32_x32", BUILD.LIB);
	addSource("../src/win32");

	checkProgram("dmd", "Cannot find dmd to compile project! You can get it from http://dlang.org/download.html");
	addCustomFlags("-version=Unicode -version=WindowsXP ");
	// Compilation
	return proceedCmd(args);
}