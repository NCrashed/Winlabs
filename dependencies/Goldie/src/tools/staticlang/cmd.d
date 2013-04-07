// Goldie: GOLD Engine for D
// Tools: StaticLang: Generate Static Goldie Language Interface
// Written in the D programming language.

module tools.staticlang.cmd;

import std.array;
import getopt = std.getopt;
import std.path;
import std.stdio;
import std.string;

import semitwist.cmdlineparser;
import semitwist.util.all;

import goldie.all;
import tools.util;

string goldiePackageDir;
static this()
{
	goldiePackageDir = absolutePath(getExecPath()~"../src/goldie/");
}

struct Options
{
	public bool   help;
	public string cgtFile;
	public string outputPackage;
	public string outputDir;

	// Generated
	public string shortPackage; // The last part of the package name
	public string cgtFileOnly;

	// Returns errorlevel program should exit immediately with.
	// If returns -1, everything is OK and program should continue without exiting.
	int process(string[] args)
	{
		auto infoHeader = helpInfoHeader("StaticLang", "2009-2012 Nick Sabalausky");
		auto helpScreen =
			infoHeader ~ "\n\n" ~ `
Generates static Goldie language interface.

Usage: goldie-staticlang [options] cgt-file [options]

Examples:
  goldie-staticlang langs/lang.cgt
      Creates "goldie/staticlang/lang/*.d", each
      containing "module goldie.staticlang.lang.*;"

  goldie-staticlang langs/lang.cgt --dir foo/src --pack myapp.mylang
  goldie-staticlang langs/lang.cgt --dir=foo/src --pack=myapp.mylang
      Creates "foo/src/myapp/mylang/*.d", each
      containing "module myapp.mylang.*;"

--help, /?          Displays this help screen
-p, --pack <name>   Name of output package (default: goldie.staticlang.{cgt})
-d, --dir <dir>     Directory of package root (default: current directory)
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
			"help",    &help,
			"p|pack",  &outputPackage,
			"d|dir",   &outputDir
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
			stderr.writeln("Must specify a cgt file.");
			stderr.writeln(suggestHelpMsg);
			return 1;
		}

		if(args.length > 2)
		{
			stderr.writeln("Can only specify one cgt file.");
			stderr.writeln(suggestHelpMsg);
			return 1;
		}

		cgtFile = args[1];
		cgtFileOnly = cgtFile.baseName();
		
		if(outputPackage == "")
		{
			shortPackage = cgtFile.stripExtension();
			outputPackage = "goldie.staticlang."~shortPackage;
		}
		else
		{
			size_t i = outputPackage.locatePrior('.');

			if(i == outputPackage.length-1)
				outputPackage = outputPackage[0..$-1];
				
			if(i == outputPackage.length)
				shortPackage = outputPackage;
			else
				shortPackage = outputPackage[i+1..$];
			
			//TODO: Ensure shortPackage (and outputPackage) is a valid ident
		}
		
		if(outputDir == "")
			outputDir = ".";
		outputDir = absolutePath(outputDir);
		outputDir = outputDir~dirSep~replace(outputPackage, ".", dirSep)~dirSep;
		
		//mixin(traceVal!("outputDir       "));
		//mixin(traceVal!("goldiePackageDir"));

		outputDir        = buildNormalizedPath(outputDir       );
		goldiePackageDir = buildNormalizedPath(goldiePackageDir);
		outputDir        ~= "/";
		goldiePackageDir ~= "/";

		if(outputDir == goldiePackageDir)
		{
			stderr.writeln("Error: Output directory is the same as Goldie's package source.");
			stderr.writeln("This is disallowed in order to prevent overwriting Goldie's source.");
			stderr.writeln("Please set a different output directory.");
			stderr.writeln();
			stderr.writeln(suggestHelpMsg);
			return 1;
		}

		return -1; // All ok
	}
}
