// Goldie: GOLD Engine for D
// Tools: Parse
// Written in the D programming language.

module tools.parse.cmd;

import std.conv;
import std.file;
import getopt = std.getopt;
static import std.path;
import std.stdio;
import std.string;

import semitwist.cmdlineparser;
import semitwist.treeout;
import semitwist.util.all;

import goldie.all;
import tools.util;

struct Options
{
	public bool   help;
	public string langFile;
	public string inputFilename;

	public string parseTreeOut;
	public string tokensOut;

	private bool noParseTree;
	private bool noTokens;

	public bool   pretty;
	public string outputType="json";
	public bool   debugOut;

	// Generated
	public TreeFormatter formatter;
	public bool   saveParseTree;
	public bool   saveTokens;
	public string lang;
	public string langSrc;
	public string langDir;

	// Returns errorlevel program should exit immediately with.
	// If returns -1, everything is OK and program should continue without exiting.
	int process(string[] args)
	{
		auto infoHeader = helpInfoHeader("Parse", "2009-2012 Nick Sabalausky");
		auto helpScreen =
			infoHeader ~ "\n\n" ~ `
Parses a source file according to a cgt file and saves the result.

Usage: goldie-parse [options] source-file [options]

Examples:
    goldie-parse lang/valid_sample2.calc
    goldie-parse lang/valid_sample2.calc --lang=lang/calc.cgt

If --lang is not specified, goldie-parse will look in Goldie's own 'lang'
subdirectory for a CGT file with a name matching the source file's extension.

--help, /?         Displays this help screen
-l, --lang <cgt>   CGT file of language (default: "{goldie}/lang/{src ext}.cgt")

--pto <filename>   Parse tree output filename
--tko <filename>   Token output filename
--no-pt            Don't save parse tree
--no-tk            Don't save tokens
-p, --pretty       Pretty format output
-t, --type <type>  Output type: "json" or "xml" (default: "json")
--debug            Display debug information
			`.strip()~"\n";

		if(args.length == 1)
		{
			write(helpScreen);
			return 0;
		}

		getopt.endOfOptions = "";
		try getopt.getopt(
			args,
			getopt.config.caseSensitive,
			"help",      &help,
			"l|lang",    &langFile,
			"pto",       &parseTreeOut,
			"tko",       &tokensOut,
			"no-pt",     &noParseTree,
			"no-tk",     &noTokens,
			"p|pretty",  &pretty,
			"t|type",    &outputType,
			"debug",     &debugOut
		);
		catch(Exception e)
		{
			stderr.writeln(e.msg);
			stderr.writeln(suggestHelpMsg);
			return 1;
		}
		
		if(help || args.contains("/?"))
		{
			write(helpScreen);
			return 0;
		}

		if(args.length < 2)
		{
			stderr.writeln("Must specify a source file.");
			stderr.writeln(suggestHelpMsg);
			return 1;
		}

		if(args.length > 2)
		{
			stderr.writeln("Can only specify one source file.");
			stderr.writeln(suggestHelpMsg);
			return 1;
		}

		inputFilename = args[1];
		saveParseTree = !noParseTree;
		saveTokens    = !noTokens;
		
		if(outputType != "json" && outputType !=  "xml")
		{
			stderr.writeln("Valid output types are 'json' and 'xml', not '", outputType, "'.");
			stderr.writeln(suggestHelpMsg);
			return 1;
		}
		
		if(parseTreeOut == "")
			parseTreeOut = inputFilename~".pt."~outputType;
		if(!saveParseTree)
			parseTreeOut = "";
			
		if(tokensOut == "")
			tokensOut = inputFilename~".tk."~outputType;
		if(!saveTokens)
			tokensOut = "";
		
		if(saveParseTree || saveTokens)
			formatter = getFormatter(outputType, pretty);
		
		if(langFile == "")
		{
			auto ext = std.path.extension(inputFilename);
			if(ext.length > 0) // Remove leading dot
				ext = ext[1..$];
				
			lang = text(getExecPath(), "../lang/", ext);
			langFile = lang ~ ".cgt";
		}
		
		lang = std.path.stripExtension(langFile);
		langSrc = lang ~ ".grmp";
		if(!exists(langSrc))
		{
			string langSrcAlt = lang~".grm";
			if(exists(langSrcAlt))
				langSrc = langSrcAlt;
		}
		
		return -1; // All ok
	}

	private TreeFormatter getFormatter(string type, bool pretty)
	{
		TreeFormatter formatter = 
			(type=="xml"  &&  pretty)? formatterPrettyXML   :
			(type=="xml"  && !pretty)? formatterTrimmedXML  :
			(type=="json" &&  pretty)? formatterPrettyJSON  :
			(type=="json" && !pretty)? formatterTrimmedJSON :
			null;
		return formatter;
	}
}
