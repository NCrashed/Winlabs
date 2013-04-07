// Goldie: GOLD Engine for D
// Tools: Update Server Docs
// Written in the D programming language.

/++


$(WEB http://www.semitwist.com/goldie/, Goldie Homepage)

Author:
$(WEB www.semitwist.com, Nick Sabalausky)
+/

module tools.dumpcgt.main;

import std.array;
import std.file;
import std.path;
import std.process;
import std.range;
import std.stdio;
import std.string;

import semitwist.util.all;

import goldie.all;
import tools.util;

alias std.process.environment environment;

version(DigitalMars)
{
	static import std.compiler;
	static if(std.compiler.version_minor < 54)
	{
		pragma(msg,
			"updateServerDocs needs at least DMD 2.054.\n"~
			"But the rest of Goldie is fine with 2.052 and up."
		);
		static assert(false, "Halting...");
	}
}

string goldieDocsDir;
immutable htmlFilename = "index.html";

// 1: Path to doc root, 2: Path to archives page
// 3: Ver of archived page, 4: Latest ver
// 5: Middle paragraph
enum oldVersionParagraph = `
	<p>
		The last version of Goldie's documentation to have this page was
		<span style="font-weight: bold;">%3$s</span>, which is archived
		<a href="%1$s%3$s/%2$s">here</a>.
	</p>
`.normalize().indent();

enum goneHtml = `
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
	<html xmlns="http://www.w3.org/1999/xhtml">

	<html>
	<head>
		<title>Goldie</title>
		<link rel="stylesheet" type="text/css" href="%1$stheme.css" />
	</head>
	<body>
		<p>This page no longer exists.</p>
%5$s
		<p>
			The documentation for the latest version of Goldie
			(<span style="font-weight: bold;">%4$s</span>)
			is <a href="%1$s">here</a>.
		</p>
	</body>
	</html>
`.normalize();

bool isVerDirectory(string path)
{
	return path[goldieDocsDir.length-1..$].startsWith(`/v`, `\v`) != 0;
}

Ver[] findVers()
{
	// Find exiting versions
	bool[Ver] existingVers;
	foreach(string filename; dirEntries(goldieDocsDir, SpanMode.breadth))
	
	if(isVerDirectory(filename))
	{
		auto verFound = filename[goldieDocsDir.length+1..$];
		version(Windows)
			verFound = verFound.replace(`\`, `/`);
		verFound = verFound[0..verFound.locate('/')];
		
		existingVers[verFound.toVer()] = true;
	}
	
	// Convert AA keys into sorted array
	Ver[] existingVersArr;
	foreach(ver; existingVers.keys.sort)
		existingVersArr ~= ver;
	
	return existingVersArr;
}

Ver findLastVer(Ver[] existingVers, string relativeFilePath)
{
	foreach(ver; retro(existingVers))
	if(exists(goldieDocsDir~"v"~ver.toString()~dirSeparator~relativeFilePath))
		return ver;

	return Ver([0]);
}

string pathToRoot(string relativeFilePath)
{
	version(Windows)
		relativeFilePath = relativeFilePath.replace(`\`, `/`);

	auto depth = count(relativeFilePath, `/`);
	
	string ret;
	foreach(i; 0..depth)
		ret ~= "../";
	
	return ret;
}

int main(string[] args)
{
	if(args.length != 3 || args[1] == "--help" || args[1] == "/?")
	{
		enum helpInfo = ("
			Usage:   ./updateServerDocs {version} {path to docs target}
			Example: ./updateServerDocs 0.5 /mnt/my-server-via-sshfs/www/goldie

			It's suggested to use sshfs to connect to the server so you can
			have this utility modify the server directly. But make a backup first!
		").normalize();
		
		writeln(helpInfoHeader("Update Server Docs", "2011-2012 Nick Sabalausky"));
		writeln();
		writeln(helpInfo);
		return 1;
	}
	
	immutable newVer = args[1];
	goldieDocsDir = args[2];
	if(goldieDocsDir.endsWith(`\`, `/`) == 0)
		goldieDocsDir ~= dirSeparator;

	auto existingVers = findVers();

	// Replace all existing "latest" pages with "page gone" message
	foreach(string filepath; dirEntries(goldieDocsDir, SpanMode.breadth))
	if(filepath.baseName == htmlFilename)
	if(!filepath.isVerDirectory())
	{
		auto relativePath = filepath[goldieDocsDir.length .. $-htmlFilename.length];

		auto lastVer = findLastVer(existingVers, relativePath).toString;
		auto html = goneHtml;
		if(lastVer != "0")
			html = html.replace("%5$s", oldVersionParagraph);
		
		auto f = File(filepath, "w");
		f.writefln(html, pathToRoot(relativePath), relativePath, "v"~lastVer, "v"~newVer, "");
	}
	
	version(Windows)
	{
		system(`mkdir "` ~ goldieDocsDir ~ `\v` ~ newVer ~ `"`);
		system(`xcopy /E /Q /Y /I release\PublicDocs\docs "` ~ goldieDocsDir ~ `\v` ~ newVer ~ `"`);
		system(`xcopy /E /Q /Y /I release\PublicDocs\docs "` ~ goldieDocsDir ~ `"`);
	}
	else version(Posix)
	{
		system(`mkdir "` ~ goldieDocsDir ~ `/v` ~ newVer ~ `"`);
		system(`cp -rf release/PublicDocs/docs/* "` ~ goldieDocsDir ~ `/v` ~ newVer ~ `"`);
		system(`cp -rf release/PublicDocs/docs/* "` ~ goldieDocsDir ~ `"`);
	}
	else
		static assert(0, "Platform not supported");
	
	return 0;
}
