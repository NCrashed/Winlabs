// Goldie: GOLD Engine for D
// Written in the D programming language.

/++

This module contains common utility functions for Goldie's tools.

As with all of Goldie, you're certainly free to use this or adapt it for you
own use (in occordance with The zlib/libpng License). But, as-is, this module
is probably only useful for Goldie's tools.

+/

module tools.util;

import std.conv;
import std.path;
import std.stdio;
import std.string;

import semitwist.util.all;

import goldie.all;

/// The directory in which to look for language files
/// whenever the language's filename isn't given.
/// This should always be terminated with a path separator.
private string defaultLangDir_;
@property string defaultLangDir()
{
	if(!defaultLangDir_)
		defaultLangDir_ = getExecPath()~"../lang/";

	return defaultLangDir_;
}

string helpInfoHeader(string programName, string copyrightInfo)
{
	return
	("
		Goldie v"~goldieVerStr~" - "~programName~"
		Copyright (c) "~copyrightInfo~"
		See LICENSE.txt for license info
		Site: http://www.semitwist.com/goldie/
	").normalize();
}

immutable suggestHelpMsg = "Run with --help to see usage.";

string inferLanguageOf(string sourceFilename)
{
	auto ext = sourceFilename.extension();
	if(ext.length > 0) // Remove leading dot
		ext = ext[1..$];

	return ext;
}

string inferLanguageFilenameOf(string sourceFilename)
{
	return getDefaultLanguageFilename(inferLanguageOf(sourceFilename));
}

string getDefaultLanguageFilename(string language)
{
	string dir = defaultLangDir;
	if(!dir.endsWith(dirSep))
		dir = dir~dirSep;

	return dir~language~".cgt";
}
