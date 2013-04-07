#!/usr/bin/rdmd
/// Скрипт автоматической компиляции проекта под Linux и Windows
/** 
 * Очень важно установить пути к зависимостям (смотри дальше), 
 */
module compile;

import dmake;

import std.stdio;
import std.process;

//======================================================================
//							Основная часть
//======================================================================
int main(string[] args)
{
	// Клиент
	addCompTarget("semitwist", "./bin", "semitwist", BUILD.LIB);
	addSource("src/semitwist/util");
	addSingleFile("src/semitwist/treeout.d");
	addSingleFile("src/semitwist/refbox.d");
	addSingleFile("src/semitwist/cmdlineparser.d");

	checkProgram("dmd", "Cannot find dmd to compile project! You can get it from http://dlang.org/download.html");
	// Компиляция!
	return proceedCmd(args);
}